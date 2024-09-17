# Copyright (C) 2022-2024 Heptazhou <zhou@0h7z.com>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

using OrderedCollections: LittleDict as LDict
using OrderedCollections: OrderedDict as ODict
using TOML: TOML
using YAML: YAML, yaml

const COMPRESS = "zstdmt -17 -M1024M --long"
const NAME, MAIL = "Seele", "seele@0h7z.com"
const PACKAGER = "$NAME <$MAIL>"
const PUSH_NOP = "Everything up-to-date"
const StrOrSym = Union{AbstractString, Symbol}
const URL_AUR = "https://aur.archlinux.org"
const URL_DEB = "https://deb.debian.org/debian"
const YAML.yaml(xs...) = join(map(yaml, xs), "\n")
macro S_str(string)
	:(Symbol($string))
end
const cquote(s::StrOrSym) = "\$'$(escape(s, "'"))'"
const escape(s::StrOrSym, xs...; kw...) = escape_string(s, xs...; kw...)
const escape(sym::Symbol, xs...; kw...) = escape(string(sym), xs...; kw...)
const mirror = [
	raw"https://mirrors.dotsrc.org/archlinux/$repo/os/$arch"
	raw"https://mirrors.kernel.org/archlinux/$repo/os/$arch"
]

const ACT_ARTIFACT(pat::StrOrSym) = ODict(
	S"uses" => S"actions/upload-artifact@v4",
	S"with" => ODict(S"compression-level" => 0, S"path" => pat),
)
const ACT_CHECKOUT(ref::StrOrSym) = ACT_CHECKOUT(
	S"path" => Symbol(ref),
	S"ref"  => Symbol(ref),
)
const ACT_CHECKOUT(xs::Pair...) = ODict(
	S"uses" => S"actions/checkout@v4",
	S"with" => ODict(S"persist-credentials" => false, xs...),
)
const ACT_GH(cmd::StrOrSym, envs::Pair...) = ACT_RUN(
	cmd, envs...,
	S"GH_REPO"  => S"${{ github.repository }}",
	S"GH_TOKEN" => S"${{ secrets.PAT }}",
)
const ACT_INIT(cmd::StrOrSym, envs::Pair...) = ACT_RUN("""
	uname -a
	mkdir ~/.ssh -p && cd /etc/pacman.d
	echo -e 'Server = $(mirror[1])' >> mirrorlist
	echo -e 'Server = $(mirror[2])' >> mirrorlist
	tac mirrorlist > mirrorlist~ && mv mirrorlist{~,} && cd /etc
	sed -r 's/^(COMPRESSZST)=.*/\\1=($COMPRESS)/' -i makepkg.conf
	sed -r 's/^#(MAKEFLAGS)=.*/\\1="-j`nproc`"/' -i makepkg.conf
	sed -r 's/^#(PACKAGER)=.*/\\1="$PACKAGER"/' -i makepkg.conf
	pacman-key --init""", """
	pacman -Syu --noconfirm git pacman-contrib
	sed -r 's/\\b(EUID)\\s*==\\s*0\\b/\\1 < -0/' -i /bin/makepkg
	makepkg --version""", cmd, envs...,
)
const ACT_INIT(pkg::Vector{String}) = ACT_INIT(
	Symbol(join(["pacman -S --noconfirm"; pkg], " ")),
)
# const ACT_PUSH(msg::StrOrSym; m = cquote(msg)) = nothing
const ACT_RUN(cmd::StrOrSym, envs::Pair...) = ODict(
	S"run" => cmd, S"env" => ODict(envs...),
)
const ACT_RUN(cmd::StrOrSym...) = ACT_RUN.([cmd...])
const ACT_RUN(cmd::StrOrSym) = ODict(S"run" => cmd)
# const ACT_SYNC(pkgbase::StrOrSym) = nothing
# const ACT_UPDT(dict::AbstractDict, rel::StrOrSym) = nothing

const JOB_MSVC(commit::StrOrSym, tag::StrOrSym) = ODict(
	S"container" => ODict(
		S"image" => S"archlinux:base-devel",
		S"volumes" => ["/:/mnt"],
	),
	S"runs-on" => S"ubuntu-latest",
	S"steps" => [
		ACT_RUN("""
			cd /mnt
			du -hd1 opt usr
			rm -vrf opt/{ghc,hostedtoolcache}        | wc -l
			rm -vrf usr/{local,share/{dotnet,swift}} | wc -l
			du -hd1 opt usr"""
		)
		ACT_INIT(["github-cli", "julia", "msitools", "python-pip", "tree"])
		ACT_CHECKOUT(
			S"path" => Symbol("firefox"),
			S"ref" => Symbol(commit),
		)
		ACT_RUN.([
			"""
			cd firefox && git log --date=iso --show-signature
			ln -s mach /bin/mach -r && export MOZBUILD_STATE_PATH=/tmp/moz
			curl -LO https://github.com/Heptazhou/Firefox/raw/github/vs.jl
			mkdir -p \$MOZBUILD_STATE_PATH && julia vs.jl / && cd .. && pwd
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

function make_vs(commit::StrOrSym, tag::StrOrSym)
	f = ".github/workflows/VS.yml"
	mkpath(dirname(f))
	write("version.txt", tag, "\n")
	write(f,
		yaml(
			S"on" => ODict(
				S"workflow_dispatch" => nothing,
				S"push" => ODict(
					S"branches" => ["github"],
					S"paths"    => ["version.txt"],
				),
			),
			S"jobs" => ODict(
				S"make_vs" => JOB_MSVC(commit, tag),
			),
		),
	)
end

branch = sort((f = "branch.toml") |> TOML.parsefile)
write(f, sprint(TOML.print, branch))
make_vs(branch["FIREFOX_NIGHTLY_129_END"], "v129")

