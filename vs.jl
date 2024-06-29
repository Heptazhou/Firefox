# Copyright (C) 2023-2024 Heptazhou <zhou@0h7z.com>
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

# [compat]
# julia = "≥ 1"

const sh(c::String) = run(`sh -c $c`)

const py = "taskcluster/scripts/misc/get_vs.py"

const vs = "build/vs/vs2022.yaml"

isempty(ARGS) || let moz = "\${MOZBUILD_STATE_PATH:=/moz}"
	sh.(["mach python --virtualenv=build $py $vs $moz/vs"])
	sh.(["mach clobber", "tree -La 2 $moz/vs"])
	sh.(["tar IfCc \"zstdmt -17 -M1024M --long\" $moz/vs.tar.zst $moz vs"])
end

