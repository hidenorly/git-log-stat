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

require "./ExecUtil"
require 'shellwords'

class GitUtil
	def self.ensureSha1(sha1, gitPath=nil)
		# TODO : ensure SHA1
		if gitPath && sha1.to_s.downcase == "tail" then
			sha1 = getTailCommitId(gitPath)
		end
		return sha1
	end

	def self._ensureSha1(sha1)
		sha= sha1.to_s.match(/[0-9a-f]{5,40}/)
		return sha ? sha[0] : nil
	end

	def self.ensureShas(shas, gitPath=nil)
		result = []
		shas.each do | aSha |
			result << ensureSha1(aSha, gitPath)
		end

		return result
	end

	def self.containCommitOnBranch?(gitPath, commitId)
		return ExecUtil.hasResult?("git rev-list HEAD | grep #{commitId}", gitPath)
	end

	def self.getAllCommitIdList(gitPath)
		exec_cmd = "git rev-list HEAD"

		return ExecUtil.getExecResultEachLine(exec_cmd, gitPath, true)
	end

	def self.containCommitInGit?(gitPath, commitId)
		return ExecUtil.hasResult?("git show #{commitId}", gitPath)
	end

	def self.getCommitIdList(gitPath, fromRevision=nil, toRevision=nil, gitOptions=nil)
		exec_cmd = "git log --pretty=\"%H\" --no-merges"
		exec_cmd += " #{fromRevision}...#{toRevision}" if fromRevision && toRevision
		exec_cmd += " #{gitOptions}" if gitOptions
		exec_cmd += " 2>/dev/null"

		return ExecUtil.getExecResultEachLine(exec_cmd, gitPath)
	end

	def self.commitIdListOflogGrep(gitPath, key, gitOptions=nil)
		exec_cmd = "git log --pretty=\"%H\""
		exec_cmd += " --grep=#{Shellwords.shellescape(key)}" if key
		exec_cmd += " #{gitOptions}" if gitOptions
		exec_cmd += " 2>/dev/null"

		return ExecUtil.getExecResultEachLine(exec_cmd, gitPath)
	end

	def self.show(gitPath, commitId, gitOptions=nil)
		exec_cmd = "git show #{commitId}"
		gitOptions = " "+gitOptions if gitOptions && !gitOptions.start_with?(":")
		exec_cmd += "#{gitOptions}" if gitOptions
		exec_cmd += " 2>/dev/null"

		return ExecUtil.getExecResultEachLine(exec_cmd, gitPath)
	end

	def self.getHeadCommitId(gitPath)
		result = nil
		exec_cmd = "git rev-list HEAD -1"
		exec_cmd += " 2>/dev/null"

		result = ExecUtil.getExecResultEachLine(exec_cmd, gitPath)
		return _ensureSha1(result.to_s)
	end

	def self.getTailCommitId(gitPath)
		result = nil
		exec_cmd = "git rev-list HEAD | tail -n 1"
		exec_cmd += " 2>/dev/null"

		result = ExecUtil.getExecResultEachLine(exec_cmd, gitPath)
		return _ensureSha1(result.to_s)
	end

	def self.getLogNumStat(gitPath, separator="#####", gitOptions=nil)
		exec_cmd = "git log --numstat --pretty=\"#{separator}:%h:%s\""
		exec_cmd += " #{gitOptions}" if gitOptions
		exec_cmd += " 2>/dev/null"

		return ExecUtil.getExecResultEachLine(exec_cmd, gitPath)
	end
end
