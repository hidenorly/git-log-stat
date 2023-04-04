#  Copyright (C) 2022 hidenorly
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require_relative "StrUtil"

class ExecUtil
	def self.execCmd(command, execPath=".", quiet=true)
		if File.directory?(execPath) then
			exec_cmd = command
			exec_cmd += " > /dev/null 2>&1" if quiet && !exec_cmd.include?("> /dev/null")
			system(exec_cmd, :chdir=>execPath)
		end
	end

	def self.hasResult?(command, execPath=".", enableStderr=true)
		result = false

		if File.directory?(execPath) then
			exec_cmd = command
			exec_cmd += " 2>&1" if enableStderr && !exec_cmd.include?(" 2>")

			IO.popen(exec_cmd, "r", :chdir=>execPath) {|io|
				while !io.eof? do
					if io.readline then
						result = true
						break
					end
				end
				io.close()
			}
		end

		return result
	end

	def self.getExecResultEachLine(command, execPath=".", enableStderr=true)
		result = []

		if File.directory?(execPath) then
			exec_cmd = command
			exec_cmd += " 2>&1" if enableStderr && !exec_cmd.include?(" 2>")

			IO.popen(exec_cmd, "r", :chdir=>execPath) {|io|
				while !io.eof? do
					result << StrUtil.ensureUtf8(io.readline).strip
				end
				io.close()
			}
		end

		return result
	end
end
