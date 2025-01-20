# Copyright (C) 2023-2025 Heptazhou <zhou@0h7z.com>
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

const sh(c::String) = run(`sh -c $c`)

const py = "taskcluster/scripts/misc/get_vs.py"

const vs = "build/vs/vs2022.yaml"

isempty(ARGS) || let moz = raw"${MOZBUILD_STATE_PATH:=/moz}"
	cd(only(ARGS))
	@time sh("mach python --virtualenv=build $py $vs $moz/vs")
	@time sh("mach clobber")
	@time sh("tree -La 2 $moz/vs")
	@time sh("tar IfCc \"zstdmt -18 -M1024M --long\" $moz/vs.tar.zst $moz vs")
end

