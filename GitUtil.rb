#!/usr/bin/env ruby

# Copyright 2022, 2023, 2025 hidenory
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

require "set"
require "open3"
require "shellwords"
require_relative "ExecUtil"
require_relative "FileUtil"

class GitUtil
	def self.isGitDirectory(gitPath)
		return File.directory?("#{gitPath}/.git")
	end

	def self.isGitPath(gitPath)
		return isGitDirectory(gitPath)
	end

	def self.isCommitId?(sha1)
		return sha1.to_s.match?(/[0-9a-f]{5,40}/)
	end

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
		if fromRevision && toRevision then
			exec_cmd += " #{fromRevision}...#{toRevision}"
		elsif fromRevision then
			exec_cmd += " #{fromRevision}"
		end
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
		return ensureSha1(result.to_s)
	end

	def self._getTailCommits(gitPath, count = 1)
		result = nil
		exec_cmd = "git rev-list HEAD | tail -n #{count}"
		exec_cmd += " 2>/dev/null"

		result = ExecUtil.getExecResultEachLine(exec_cmd, gitPath)
		return ensureShas(result)
	end

	def self.getTailCommitId(gitPath)
		return _getTailCommits( gitPath, 1 ).to_s
	end

	def self.getActualTailCommitId(gitPath)
		result = nil
		candidate = _getTailCommits( gitPath, 2 )
		candidate.reverse_each do | aCommitId |
			numStatResult = getLogNumStatBySha1( gitPath, aCommitId )
			if !numStatResult.empty? then
				result = aCommitId
				break
			end
		end
		return result
	end

	def self._parseNumStatOneLine(aLine, separator="#####")
		filename = ""
		aResult = {:added=>0, :removed=>0}

		if !aLine.start_with?(separator) then
			added = 0
			removed = 0

			aLine.strip!
			theResult = aLine.split(" ")
			count = 0
			theResult.each do |aResult|
				found = false
				aResult.strip!

				case count
				when 0
					added = aResult.to_i
					found = true
				when 1
					removed = aResult.to_i
					found = true
				when 2
					filename = aResult
					found = true
				else
					count = 0
				end

				count = count + 1 if found
			end


			if count == 3 then
				aResult = {:added=>added, :removed=>removed}
			else
				filename = ""
			end
		end

		return filename, aResult
	end

	def self.parseNumStatPerFile(numStatResult, separator="#####")
		result = {}

		numStatResult.each do |aLine|
			aFile, aResult = _parseNumStatOneLine(aLine, separator)


			if !aFile.empty? then
				if result.has_key?(aFile) then
					theResult = result[aFile]
					theResult[:added]   = theResult[:added] + aResult[:added]
					theResult[:removed] = theResult[:removed] + aResult[:removed]
					result[aFile] = theResult
				else
					result[aFile] = aResult
				end
			end
		end

		return result
	end

	def self._parseAuthor(aLine, separator = "#####}")
		author = ""
		pos1 = aLine.index(":", separator.length+1)
		if pos1!=nil then
			pos2 = aLine.index(":", pos1+1)
			if pos2!=nil then
				author = aLine.slice(pos1+1, pos2-pos1-1)
			end
		end
		return author
	end

	def self.parseNumStatPerAuthor(numStatResult, separator="#####")
		result = {}
		author = ""

		numStatResult.each do |aLine|
			if aLine.start_with?(separator) then
				author = _parseAuthor(aLine, separator)
			else
				aFile, aResult = _parseNumStatOneLine(aLine, separator)

				if !aFile.empty? && !author.empty? then
					if result.has_key?(author) then
						theResult = result[author]
						theResult[:added]   = theResult[:added] + aResult[:added]
						theResult[:removed] = theResult[:removed] + aResult[:removed]
						result[author] = theResult
					else
						result[author] = aResult
					end
				end
			end
		end

		return result
	end


	def self.getLogNumStat(gitPath, separator="#####", gitOptions=nil, isAuthorEmail=false)
		exec_cmd = "git log --numstat"
		if isAuthorEmail then
			exec_cmd += " --pretty=\"#{separator}:%h:%ae:%s\""
		else
			exec_cmd += " --pretty=\"#{separator}:%h:%an:%s\""
		end
		exec_cmd += " #{gitOptions}" if gitOptions
		exec_cmd += " 2>/dev/null"

		return ExecUtil.getExecResultEachLine(exec_cmd, gitPath)
	end

	def self.getLogNumStatBySha1(gitPath, commitId)
		exec_cmd = "git log --numstat --pretty=\"\" #{commitId}"
		exec_cmd += " 2>/dev/null"

		return ExecUtil.getExecResultEachLine(exec_cmd, gitPath)
	end

	def self.getFilesWithGitOpts(gitPath, gitOpt = "", existingFileOnly = true)
		exec_cmd = "git log --name-only --pretty=\"\" #{gitOpt ? gitOpt : ""} | sort -u"
		result = ExecUtil.getExecResultEachLine(exec_cmd, gitPath, false, true, true)
		if existingFileOnly then
			_result = []
			result.each do |aFile|
				_result << aFile if File.exist?("#{gitPath}/#{aFile}")
			end
			result = _result
		end
		return result
	end

	def self.isCommitExistWithFileAndGitOpts(gitPath, filename, gitOpt = "")
		exec_cmd = "git log --pretty=\"%h\" #{gitOpt ? gitOpt : ""}  -- #{Shellwords.escape(filename)}"
		return ExecUtil.hasResult?(exec_cmd, gitPath, false)
	end

	STATUS_CHANGES_TO_BE_COMMITED = 0
	STATUS_CHANGES_TO_BE_COMMITED_IDENTIFIER = "Changes to be committed:"

	STATUS_CHANGES_NOT_STAGED = 1
	STATUS_CHANGES_NOT_STAGED_IDENTIFIER = "Changes not staged for commit:"
	STATUS_CHANGES_MODIFIED = "modified:"
	STATUC_CHANGES_NEWFILE = "new file:"
	STATUS_CHANGES_MODIFIED_LEN = STATUS_CHANGES_MODIFIED.length

	STATUS_UNTRACKED = 2
	STATUS_UNTRACKED_IDENTIFIER = "Untracked files:"

	STATUS_IGNORE_OTHERS = [
		'(use "git restore --staged <file>..." to unstage)',
		'(use "git add <file>..." to update what will be committed)',
		'(use "git add <file>..." to include in what will be committed)',
		'(use "git restore <file>..." to discard changes in working directory)',
		'no changes added to commit (use "git add" and/or "git commit -a")'
	]

	def self.status(gitPath, gitOpt = "")
		result_to_be_commited = []
		result_changes_not_staged = []
		result_untracked = []

		exec_cmd = "git status #{gitOpt ? gitOpt : ""}"
		result = ExecUtil.getExecResultEachLine(exec_cmd, gitPath, false, true, true)

		mode = STATUS_CHANGES_TO_BE_COMMITED
		result.each do |aLine|
			aLine = aLine.to_s.strip
			if aLine == STATUS_CHANGES_TO_BE_COMMITED_IDENTIFIER then
				mode = STATUS_CHANGES_TO_BE_COMMITED
			elsif aLine == STATUS_CHANGES_NOT_STAGED_IDENTIFIER then
				mode = STATUS_CHANGES_NOT_STAGED
			elsif aLine == STATUS_UNTRACKED_IDENTIFIER then
				mode = STATUS_UNTRACKED
			elsif STATUS_IGNORE_OTHERS.include?(aLine) then
			else
				case mode
					when STATUS_CHANGES_NOT_STAGED, STATUS_CHANGES_TO_BE_COMMITED
						begin
							pos = aLine.index(STATUS_CHANGES_MODIFIED)
							pos = aLine.index(STATUC_CHANGES_NEWFILE) if pos==nil
							if pos!=nil then
								aFile = aLine.slice(pos+STATUS_CHANGES_MODIFIED_LEN+1,aLine.length).strip
								if File.exist?(aFile)
									if mode == STATUS_CHANGES_TO_BE_COMMITED then
										result_to_be_commited << aFile
									else
										result_changes_not_staged << aFile
									end
								end
							end
						end
					when STATUS_UNTRACKED
						result_untracked << aLine if File.exist?(aLine)
				end
			end
		end

		all_modified = result_to_be_commited.clone()
		all_modified.concat( result_changes_not_staged )
		all_modified.concat( result_untracked )
		all_modified = all_modified.to_set.to_a

		return all_modified, result_to_be_commited, result_changes_not_staged, result_untracked
	end

	def self.diff(gitPath, gitOpt = "")
		exec_cmd = "git diff #{gitOpt ? gitOpt : ""}"
		return ExecUtil.getExecResultEachLine(exec_cmd, gitPath, false, false, true)
	end

	def self.add(gitPath, files, gitOpt = "")
		result = []
		foundFiles = []
		files.each do |aFile|
			foundFiles << aFile if File.exist?("#{gitPath}/#{aFile}")
		end
		if !foundFiles.empty? then
			exec_cmd = "git add #{gitOpt ? gitOpt : ""}  -- #{foundFiles.join(" ")}"
			result = ExecUtil.getExecResultEachLine(exec_cmd, gitPath, true, true, true)
		end

		return result
	end

	def self.unstange(gitPath, files, gitOpt = "")
		exec_cmd = "git restore --staged #{files.join(" ")}"
		return ExecUtil.getExecResultEachLine(exec_cmd, gitPath, true, true, true)
	end

	def self._getValue(aLine, key)
		result = nil
		aLine = aLine.to_s
		pos = aLine.index(key)
		if pos then
			result = aLine.slice( pos+key.length, aLine.length )
			result.strip!
		end
		return result
	end

	def self._getValueFromLines(lines, key)
		lines.each do |aLine|
			result = _getValue(aLine, key)
			return result if result
		end
		return ""
	end

	def self.gitBlame(gitPath, filename, line, commitId="HEAD")
		results = {}
		exec_cmd = "git blame -p #{filename} -L #{line},#{line} #{commitId}"
		result = ExecUtil.getExecResultEachLine(exec_cmd, gitPath, false, true, true)
		if !result.empty? then
			results[:commitId] = result[0].split(" ")[0]
			results[:author] = _getValueFromLines(result, "author")
			results[:authorMail] = _getValueFromLines(result, "author-mail")
			results[:theLine] = result.last.to_s.strip
		end
		return results
	end

	def self.blame(gitPath, filename, line, commitId="HEAD")
		return gitBlame(gitPath, filename, line, commitId)
	end

	# patch style
	def self.formatPatch(gitPath, commitId, outPath=nil, gitOptions=nil)
		exec_cmd = "git format-patch -1 --subject-prefix=\"\" --no-numbered --stdout #{commitId}"
		gitOptions = " "+gitOptions if gitOptions && !gitOptions.start_with?(":")
		exec_cmd += "#{gitOptions}" if gitOptions
		exec_cmd += " > #{outPath}" if outPath
		exec_cmd += " 2>/dev/null" if !exec_cmd.include?("2>")

		return ExecUtil.getExecResultEachLine(exec_cmd, gitPath)
	end

	def self.amAbort(gitPath)
		ExecUtil.execCmd("git am --abort", gitPath)
	end

	def self.apply(gitPath, aPatchPath, gitOptions="", logFile=nil, verbose=false, abortIfFail=true)
		return am(gitPath, aPatchPath, gitOptions, logFile, verbose, false, abortIfFail)
	end

	def self.am(gitPath, aPatchPath, gitOptions="", logFile=nil, verbose=false, enableCommit=true, abortIfFail=true)
		result = File.directory?(gitPath)

		if result then
			exec_cmd = enableCommit ? "git am" : "git apply"
			exec_cmd += " -3 #{gitOptions} #{Shellwords.shellescape(aPatchPath)}"
			exec_cmd += " >> #{logFile}" if logFile

			errMsg = ""
			Open3.popen3(exec_cmd, :chdir=>gitPath) do |i, o, e, w|
				while !e.eof? do
					aLine = StrUtil.ensureUtf8(e.readline).strip
					if aLine.start_with?("No changes -- Patch already applied.") then
						# Ok
					elsif aLine.start_with?("error: ") || aLine.start_with?("fatal: ") then
						# failed
						errMsg="patch failed: #{aPatchPath}"
						puts errMsg if verbose
						amAbort(gitPath) if abortIfFail
						result = false
					end
						
				end
				i.close()
				o.close()
				e.close()
			end
			FileUtil.appendLineToFile(logFile, errMsg) if errMsg && !result
		end

		return result
	end

	def self._parseMbox(commit, aLine)
		result = false
		if !commit[:id] && aLine.start_with?("From ") then
			id = aLine.split(" ")
			commit[:id] = id[1] if id.length>1
		elsif !commit[:author] && aLine.start_with?("From: ") then
			commit[:author] = aLine.slice(6, aLine.length-6)
		elsif !commit[:date] && aLine.start_with?("Date: ") then
			commit[:date] = aLine.slice(6, aLine.length-6)
		elsif !commit[:title] && aLine.start_with?("Subject: ") then
			aLine = aLine.slice(9..aLine.length)
			pos = aLine.index("[PATCH")
			if pos then
				aLine = aLine.slice(pos+6..aLine.length)
				pos = aLine.index("]")
				aLine = aLine.slice(pos+1..aLine.length) if pos
				aLine.strip!
			end
			commit[:title] = aLine
		elsif commit[:title]!=nil && commit[:title].empty? then
			commit[:title] = aLine
		elsif !commit[:changedId] && aLine.start_with?("Change-Id: ") then
			commit[:changedId] = aLine.slice(11, aLine.length-11)
		elsif aLine == "---" && !commit[:modifiedFiles] then
			commit[:modifiedFiles] = []
			commit[:modifiedFilenames] = []
		else
			result = aLine.start_with?("diff --git")
			if commit[:modifiedFiles].kind_of?(Array) then
				if aLine.include?("|") then
					commit[:modifiedFiles] << aLine
					commit[:modifiedFilenames] << aLine.split("|").at(0).strip
				else
					result = true
				end
			end
		end

		return result
	end

	def self.parsePatchFromBody(theBody)
		commit = {id:nil, title:nil, date:nil, author:nil, changedId:nil, modifiedFiles:nil, modifiedFilenames:[], message:[]}

		isHeaderFound=false
		theBody.each.each do |aLine|
			aLine = StrUtil.ensureUtf8(aLine).strip #aLine.strip!
			isTitleFound = !commit[:title].to_s.empty?
			break if _parseMbox(commit, aLine)
			isHeaderFound |= (!isTitleFound && !commit[:title].to_s.empty?)
			isHeaderFound = false if aLine.start_with?("---")
			commit[:message] << aLine if isHeaderFound && aLine
		end

		return commit
	end


	def self.parsePatch(patchPath)
		theBody = FileUtil.readFileAsArray(patchPath)
		return parsePatchFromBody(theBody)
	end


	def self._parseModifiedFile(aLine)
		filename = nil
		lines = 0
		aLine.strip!

		pos = aLine.index("|")
		if pos then
			filename = aLine.slice(0..pos-1).strip
			pos2 = filename.index(".../")
			filename = filename.slice(pos2+4..filename.length) if pos2

			aLine = aLine.slice(pos+1..aLine.length).strip
			pos = aLine.index(" ")
			lines = aLine.slice(0..pos-1).to_i if pos
		end

		return filename, lines
	end

	def self._getModifiedFiles(modfiedFiles)
		result = []

		modfiedFiles.each do |aModifiedFile|
			filename, lines = _parseModifiedFile(aModifiedFile)
			result << filename if lines
		end

		return result
	end

	def self.isSameModifiedFiles?(modifiedFiles1, modifiedFiles2, robustMode = false)
		result = false

		if modifiedFiles1 && modifiedFiles2 then
			result = (modifiedFiles1 == modifiedFiles2)

			if !result && robustMode then
				files1 = _getModifiedFiles(modifiedFiles1).sort
				files2 = _getModifiedFiles(modifiedFiles2).sort
				result = (files1 == files2)
			end
		end

		return result
	end

	def self._getModifiedLines(stream, robustMode)
		addedLines = []
		removedLines = []
		fileType = FileClassifier::FORMAT_UNKNOWN

		while !stream.eof? do
			aLine = StrUtil.ensureUtf8(stream.readline).strip
			fileType= FileClassifier.getFileType(aLine) if aLine.start_with?("+++ ")

			addedLine = (aLine.start_with?("+") && !aLine.start_with?("+++")) ? aLine.slice(1...aLine.length-1).strip : ""
			removedLine = (aLine.start_with?("-") && !aLine.start_with?("---")) ? aLine.slice(1...aLine.length-1).strip : ""

			if robustMode then
				addedLine = FileClassifier.isMeanlessLine?(addedLine, fileType) ? "" : addedLine
				removedLine = FileClassifier.isMeanlessLine?(removedLine, fileType) ? "" : removedLine
			end

			addedLines << addedLine if !addedLine.empty?
			removedLines << removedLine if !removedLine.empty?
		end

		return addedLines, removedLines
	end


	def self.isSamePatch?(patchStream1, patchStream2, robustMode=false)
		result = false

		patchHeader1 = parsePatchFromBody(patchStream1)
		patchHeader2 = parsePatchFromBody(patchStream2)

		# check modfied files
		if isSameModifiedFiles?(patchHeader1[:modifiedFiles], patchHeader2[:modifiedFiles], robustMode) then
			while !patchStream1.eof? do
				break if StrUtil.ensureUtf8(patchStream1.readline).start_with?("diff --git")
			end
			while !patchStream2.eof? do
				break if StrUtil.ensureUtf8(patchStream2.readline).start_with?("diff --git")
			end

			if !robustMode then
				if !patchStream1.eof? && !patchStream2.eof? then
					result = true
					while result && !patchStream1.eof? && !patchStream2.eof? do
						aLine1 = StrUtil.ensureUtf8(patchStream1.readline).strip
						aLine2 = StrUtil.ensureUtf8(patchStream2.readline).strip
						result = (aLine1 == aLine2)
					end
					result = false if !patchStream1.eof? || !patchStream2.eof?
				end
			else
				addedLines1, removedLines1 = _getModifiedLines(patchStream1, robustMode)
				addedLines2, removedLines2 = _getModifiedLines(patchStream2, robustMode)

				result = (addedLines1.sort == addedLines2.sort) && (removedLines1.sort == removedLines2.sort)
			end
		end

		return result
	end

	def self.containCommitOnBranch?(gitPath, commitId)
		return ExecUtil.hasResult?("git rev-list HEAD | grep #{commitId}", gitPath)
	end

	def self.contains(gitPath, commitId)
		return ExecUtil.getExecResultEachLine("git branch -a --contains=#{commitId}", gitPath, false, true, true)
	end

	def self.containCommitInGit?(gitPath, commitId)
		return ExecUtil.hasResult?("git show #{commitId}", gitPath)
	end


	def self._parseModifiedFile(aLine)
		filename = nil
		lines = 0
		aLine.strip!

		pos = aLine.index("|")
		if pos then
			filename = aLine.slice(0..pos-1).strip
			pos2 = filename.index(".../")
			filename = filename.slice(pos2+4..filename.length) if pos2

			aLine = aLine.slice(pos+1..aLine.length).strip
			pos = aLine.index(" ")
			lines = aLine.slice(0..pos-1).to_i if pos
		end

		return filename, lines
	end

	def self._getMostModifiedFile(patchBody, modifiedFiles=nil)
		# get candidate of most modified filename
		if !modifiedFiles then
			thePatch = parsePatchFromBody(patchBody)
			modifiedFiles = thePatch[:modifiedFiles]
		end
		mostModifiedFilename=nil
		modifiedLines = 0
		modifiedFiles.each do |aMofifiedFile|
			filename, lines = _parseModifiedFile(aMofifiedFile)
			if lines >= modifiedLines then
				modifiedLines = lines
				mostModifiedFilename = filename if !mostModifiedFilename
			end
		end

		# get correct filename
		if mostModifiedFilename then
			patchStream = ArrayStream.new(patchBody)
			while !patchStream.eof? do
				break if StrUtil.ensureUtf8(patchStream.readline).start_with?("diff --git")
			end
			found = false
			while !patchStream.eof? && !found do
				aLine = StrUtil.ensureUtf8(patchStream.readline).strip
				if aLine.index(mostModifiedFilename) then
					candidates = aLine.split(" ")
					candidates.each do |aCandidate|
						if aCandidate.include?(mostModifiedFilename) then
							pos = aCandidate.index("a/")
							aCandidate = aCandidate.slice(pos+2..aCandidate.length) if pos
							pos = aCandidate.index("b/")
							aCandidate = aCandidate.slice(pos+2..aCandidate.length) if pos
							mostModifiedFilename = aCandidate
							found = true
							break
						end
					end
				end
			end
		end

		return mostModifiedFilename
	end

	def self._tryMatch(gitPath, key, patchBody, gitOptions=nil, robustMode = false)
		gitOptions = "--no-merges #{gitOptions}"
		candidates = commitIdListOflogGrep(gitPath, key, gitOptions)
		candidates.each do |aCandidateId|
			theCommitBody = formatPatch(gitPath, aCandidateId)
			return aCandidateId if isSamePatch?( ArrayStream.new(theCommitBody), ArrayStream.new(patchBody), robustMode )
		end

		return nil
	end

	def self._tryMatchKeyword(gitPath, message, matchKeyword=nil, verbose=false)
		if matchKeyword then
			matchRegKey = Regexp.new(matchKeyword)
			gitOptions = "--no-merges"
			keys = message.to_s.scan(matchRegKey)
			if keys then
				keys.each do |aKeys|
					if aKeys then
						aKeys = [aKeys] if aKeys.kind_of?(String)
						aKeys.each do |key|
							candidates = commitIdListOflogGrep(gitPath, key, gitOptions)
							candidates.each do |aCandidateId|
								isFoundOnTheBranch = containCommitOnBranch?(gitPath, aCandidateId)
								puts "grep found but not on the branch:#{key}:#{gitPath}:#{aCandidateId}:#{message.slice(0,50)}" if verbose && !isFoundOnTheBranch
								return aCandidateId if isFoundOnTheBranch
							end
						end
						puts "#{aKeys} is not found on #{gitPath}" if verbose
					end
				end
			end
		end

		return nil
	end

	def self.getCommitIdFromPatch(gitPath, patchBody, onBranch=true, skipGitContain=false, robustMode=false, matchKeyword=nil, verbose=false)
		result = nil

		thePatch = parsePatchFromBody(patchBody)

		if !skipGitContain && thePatch[:id] &&
			( (onBranch && containCommitOnBranch?(gitPath, thePatch[:id])) ||
				(!onBranch && containCommitInGit?(gitPath, thePatch[:id])) ) then
			result = thePatch[:id]
		else
			result = _tryMatch(gitPath, thePatch[:changedId], patchBody, nil, robustMode) if thePatch[:changedId]
			result = _tryMatch(gitPath, thePatch[:title], patchBody, nil, robustMode) if !result && thePatch[:title]
			result = _tryMatchKeyword(gitPath, thePatch[:message].join(" "), matchKeyword, verbose) if !result & robustMode & matchKeyword
			result = _tryMatch(gitPath, nil, patchBody, "--since=\"#{thePatch[:date]}\" -- #{Shellwords.escape(_getMostModifiedFile(patchBody, thePatch[:modifiedFiles]))}", robustMode) if !result && thePatch[:date] && thePatch[:modifiedFiles] && robustMode
			# TODO: Try another method...
		end

		return result
	end


	def self.getBranchPoint(baseGitPath, baseBranch, targetGit, topicBranch)
		exec_cmd =  "diff -u <(cd #{Shellwords.shellescape(targetGit)};git rev-list --first-parent #{topicBranch})"
		exec_cmd += " <(cd #{Shellwords.shellescape(baseGitPath)}; git rev-list --first-parent #{baseBranch})"
		exec_cmd += " | sed -ne 's/^ //p' | head -1"
		exec_cmd += " 2>/dev/null"

		result = ExecUtil.getExecResultEachLine(exec_cmd, baseGitPath)
		result = ensureShas(result)
		result = getTailCommitId(baseGitPath) if !result || result.empty?
		return result
	end


	def self.checkout(gitPath, shaOrBranch, createBranch=false, gitOptions=nil)
		exec_cmd = "git checkout"
		exec_cmd += " -b" if createBranch
		exec_cmd += " #{shaOrBranch}"
		exec_cmd += " #{gitOptions}" if gitOptions
		exec_cmd += " 2>&1"

		ExecUtil.execCmd(exec_cmd, gitPath)
	end

	def self.undoCheckout(gitPath, gitOptions=nil)
		exec_cmd = "git switch -"
		exec_cmd += " #{gitOptions}" if gitOptions
		exec_cmd += " 2>&1"

		ExecUtil.execCmd(exec_cmd, gitPath)
	end

	def self.cherryPickAbort(gitPath, gitOptions=nil)
		ExecUtil.execCmd("git cherry-pick --abort", gitPath)
	end

	def self.cherryPick(gitPath, commitId, gitOptions=nil, logFile=nil, verbose=false, abortIfFail=true)
		result = File.directory?(gitPath)

		if result then
			exec_cmd = "git cherry-pick -x #{commitId}"
			exec_cmd += " >> #{logFile}" if logFile

			errMsg = ""
			Open3.popen3(exec_cmd, :chdir=>gitPath) do |i, o, e, w|
				while !e.eof? do
					aLine = StrUtil.ensureUtf8(e.readline).strip
					if aLine.start_with?("error:") then
						# failed
						errMsg = "cherry-pick failed: #{commitId}"
						puts errMsg if verbose
						cherryPickAbort(gitPath) if abortIfFail
						result = false
					end
						
				end
				i.close()
				o.close()
				e.close()
			end
			FileUtil.appendLineToFile(logFile, errMsg) if errMsg && !result
		end

		return result
	end

	def self.reset(gitPath, sha1, gitOptions=nil)
		exec_cmd = "git reset"
		exec_cmd += " #{sha1}"
		exec_cmd += " #{gitOptions}" if gitOptions
		exec_cmd += " 2>&1"

		ExecUtil.execCmd(exec_cmd, gitPath)
	end


	def self.revertAbort(gitPath, gitOptions=nil)
		ExecUtil.execCmd("git revert --abort", gitPath)
	end

	def self.revert(gitPath, commitId, gitOptions=nil, logFile=nil, verbose=false, abortIfFail=true)
		result = File.directory?(gitPath)

		if result then
			exec_cmd = "git revert #{commitId} --no-edit"
			exec_cmd += " >> #{logFile}" if logFile

			errMsg = ""
			Open3.popen3(exec_cmd, :chdir=>gitPath) do |i, o, e, w|
				while !e.eof? do
					aLine = StrUtil.ensureUtf8(e.readline).strip
					if aLine.start_with?("error:") then
						# failed
						errMsg = "revert failed: #{commitId}"
						puts errMsg if verbose
						revertAbort(gitPath) if abortIfFail
						result = false
					end
						
				end
				i.close()
				o.close()
				e.close()
			end
			FileUtil.appendLineToFile(logFile, errMsg) if errMsg && !result
		end

		return result
	end

	def self.archive(gitPath, outputPath, gitOptions=nil, sha1="HEAD")
		exec_cmd = "git archive -o #{Shellwords.shellescape(outputPath)}"
		exec_cmd += " #{sha1}" if sha1
		exec_cmd += " #{gitOptions}" if gitOptions
		exec_cmd += " 2>&1"

		ExecUtil.execCmd(exec_cmd, gitPath)
	end

	def self.remoteAdd(dstGitPath, repoName, srcGitPath, gitOptions=nil)
		exec_cmd = "git remote add #{Shellwords.shellescape(repoName)} #{Shellwords.shellescape(srcGitPath)}"
		exec_cmd += " #{gitOptions}" if gitOptions
		exec_cmd += " 2>&1"

		ExecUtil.execCmd(exec_cmd, dstGitPath)
	end

	def self.remoteRemove(gitPath, repoName, gitOptions=nil)
		exec_cmd = "git remote rm #{Shellwords.shellescape(repoName)}"
		exec_cmd += " #{gitOptions}" if gitOptions
		exec_cmd += " 2>&1"

		ExecUtil.execCmd(exec_cmd, gitPath)
	end
end
