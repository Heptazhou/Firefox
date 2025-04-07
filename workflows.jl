# Copyright (C) 2022-2025 Heptazhou <zhou@0h7z.com>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, version 3.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

using Exts
using TOML: TOML
using YAML: yaml

const COMPRESS = "zstdmt -18 -M1024M --long"
const PACKAGER = "Seele <seele@0h7z.com>"
const PUSH_NOP = "Everything up-to-date"
const URL_AUR  = "https://aur.archlinux.org"
const URL_DEB  = "https://deb.debian.org/debian"
const VPY, _   = "3.11", "../Firefox/mach"

const cquote(s::SymOrStr)::String = "\$'$(escape(s, "'"))'"
const escape(s::SymOrStr, xs...; kw...) = escape_string(s, xs...; kw...)
const escape(sym::Symbol, xs...; kw...) = escape(string(sym), xs...; kw...)
const mirror = String[
	raw"https://mirrors.kernel.org/archlinux/$repo/os/$arch"
	raw"https://mirrors.dotsrc.org/archlinux/$repo/os/$arch"
]

const ACT_ARTIFACT(pat::SymOrStr) = LDict(
	S"uses" => S"actions/upload-artifact@v4",
	S"with" => LDict(S"compression-level" => 0, S"path" => pat),
)
const ACT_CHECKOUT(ref::SymOrStr) = ACT_CHECKOUT(
	S"path" => Symbol(ref),
	S"ref"  => Symbol(ref),
)
const ACT_CHECKOUT(xs::Pair...) = LDict(
	S"uses" => S"actions/checkout@v4",
	S"with" => ODict(S"persist-credentials" => false, xs...),
)
const ACT_GH(cmd::SymOrStr, envs::Pair...) = ACT_RUN(
	cmd, envs...,
	S"GH_REPO"  => S"${{ github.repository }}",
	S"GH_TOKEN" => S"${{ secrets.PAT }}",
)
const ACT_INIT(cmd::SymOrStr, envs::Pair...) = ACT_RUN("""
	uname -a
	mkdir ~/.ssh -p && cd /etc/pacman.d && cat \\
	<<< 'Server = $(mirror[1])' \\
	<<< 'Server = $(mirror[2])' \\
	<<< `< mirrorlist` > mirrorlist && cd /etc
	sed -r 's/^(COMPRESSZST)=.*/\\1=($COMPRESS)/' -i makepkg.conf
	sed -r 's/^#(MAKEFLAGS)=.*/\\1="-j`nproc`"/' -i makepkg.conf
	sed -r 's/^#(PACKAGER)=.*/\\1="$PACKAGER"/' -i makepkg.conf
	pacman-key --init""", """
	pacman -Syu --noconfirm git pacman-contrib
	git config --system log.date iso8601
	sed -r 's/\\b(EUID)\\s*==\\s*0\\b/\\1 < -0/' -i /bin/makepkg
	makepkg --version""", cmd, envs...,
)
const ACT_INIT(pkg::Vector{String}) = ACT_INIT(
	Symbol(join(["pacman -S --noconfirm"; pkg], " ")),
)
# const ACT_PUSH(msg::SymOrStr; m = cquote(msg)) = nothing
const ACT_RUN(cmd::SymOrStr, envs::Pair...) = LDict(
	S"run" => cmd, S"env" => ODict(envs...),
)
const ACT_RUN(cmd::SymOrStr...) = ACT_RUN.([cmd...])
const ACT_RUN(cmd::SymOrStr) = LDict(S"run" => cmd)
# const ACT_SYNC(pkgbase::SymOrStr) = nothing
# const ACT_UPDT(dict::AbstractDict, rel::SymOrStr) = nothing

const JOB_MSVC(commit::SymOrStr, tag::SymOrStr) = LDict(
	S"container" => LDict(
		S"image" => S"archlinux:base-devel",
		S"volumes" => ["/:/mnt"],
	),
	S"runs-on" => S"ubuntu-latest",
	S"steps" => [
		ACT_RUN(let x = raw"wc -l | xargs -I# echo $'rm:\t#'"
			"""
			cd /mnt
			du -hd0 opt/ usr/ && du -hd1 opt/* usr/{lib,local{/lib,},share}
			rm -vrf opt/{az,google,hostedtoolcache,microsoft,pipx}    | $x
			rm -vrf usr/{local,share/{az_*,dotnet,miniconda,swift}}   | $x
			rm -vrf usr/lib/{firefox,google-*,heroku,jvm,llvm-*,mono} | $x
			du -hd0 opt/ usr/"""
		end)
		ACT_INIT(["github-cli", "julia", "msitools", "tree"])
		ACT_RUN(let url = "https://github.com/0h7z/aur/releases/download"
			"""
			sed -re 's/(SigLevel) .+/\\1 = Optional/g' -i /etc/pacman.conf
			pacman -U --noconfirm \\
			$url/python311-v3.11.11-1/python311-3.11.11-1-x86_64.pkg.tar.zst
			python$VPY -VV"""
		end)
		ACT_CHECKOUT(
			S"path" => Symbol("firefox"),
			S"ref" => Symbol(commit),
		)
		ACT_RUN.([
			"""
			cd firefox && git log --show-signature
			sed -r 's|^#(!/usr/bin/env python).*|#\\1$VPY|' -i mach
			ln -s mach /bin/mach -r && export MOZBUILD_STATE_PATH=/tmp/moz
			curl -LO https://github.com/Heptazhou/Firefox/raw/github/vs.jl
			mkdir -p \$MOZBUILD_STATE_PATH && julia vs.jl . && cd .. && pwd
			mv -vt . \$MOZBUILD_STATE_PATH/*.tar.zst"""
			S"ls -lav *.tar.zst"
		])
		ACT_ARTIFACT("*.tar.zst")
		ACT_GH("""
			gh version
			gh release delete \$GH_TAG --cleanup-tag -y || true
			gh release create \$GH_TAG *.tar.zst --target \\
			  $commit --title \$GH_TAG""",
			S"GH_TAG" => Symbol(tag),
		)
	],
)

function make_vs(commit::SymOrStr, tag::SymOrStr)
	q = "version.txt"
	f = ".github/workflows/VS.yml"
	mkpath(dirname(f))
	write(q, tag, "\n")
	write(f,
		yaml(
			:on => LDict(
				:workflow_dispatch => nothing,
				:push => LDict(
					:branches => ["github"],
					:paths    => [q],
				),
			),
			:jobs => LDict(
				:make_vs => JOB_MSVC(commit, tag),
			),
			delim = "\n",
		),
	)
end

# https://github.com/Heptazhou/Firefox/blob/master/.hgtags
# https://github.com/mozilla/gecko-dev/blob/master/.hgtags
branch = sort!((f = "branch.toml") |> ODict ∘ TOML.parsefile)
write(f, sprint(TOML.print, branch))
make_vs(branch["FIREFOX_NIGHTLY_136_END"], :v136)

