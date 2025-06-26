require "octokit"
require "base64"
require "json"


module AutoChangelog
  class GithubClient
    def initialize(changelog_path)
      @changelog_path = changelog_path
      @repo = ENV['GITHUB_REPOSITORY']
      @token = ENV['GITHUB_TOKEN']
      @client = Octokit::Client.new(access_token: @token)
      @event = JSON.parse(File.read(ENV['GITHUB_EVENT_PATH']))
      @pr_number = @event.dig('pull_request', 'number')
      @pr_branch = @event.dig('pull_request', 'head', 'ref')
    end

    def update_changelog(section:, suggested_entry:, mode: "comment")
      case mode
      when "comment"
        suggest_changelog_update(section: section, suggested_entry: suggested_entry)
      when "commit"
        commit_changelog_update(section: section, suggested_entry: suggested_entry)
      else
        raise "Unknown mode: #{mode}"
      end
    end

    def fetch_pr_info
      pr = @client.pull_request(@repo, @pr_number)
      files = @client.pull_request_files(@repo, @pr_number).map(&:filename)

      {number: @pr_number, title: pr.title, body: pr.body, files: files}
    end

    private

    def suggest_changelog_update(section:, suggested_entry:)
      file_info = fetch_file_info(section)

      lines = file_info[:lines]
      insert_index = file_info[:insert_index]

      context_lines = lines[insert_index, 2] || []
      new_entry_line = "- #{suggested_entry.strip}"

      suggestion = <<~SUGGESTION
        #### 💡 Suggested changelog update for "#{section}":

        ```suggestion
        #{(context_lines + [new_entry_line]).join.strip}
        ```
      SUGGESTION

      @client.add_comment(@repo, @pr_number, suggestion)

      puts "[AutoChangelog] ✅ Added changelog suggestion comment to PR #{@pr_number}"
    end

    def commit_changelog_update(section:, suggested_entry:)
      file_info = fetch_file_info(section)

      lines = file_info[:lines]
      insert_index = file_info[:insert_index]
      file_sha = file_info[:file_sha]

      new_entry_line = "- #{suggested_entry.strip}\n"
      lines.insert(insert_index + 1, new_entry_line)

      updated_content = lines.join

      @client.update_contents(
        @repo,
        @changelog_path,
        "chore: updated #{@changelog_path} for PR ##{@pr_number}",
        file_sha,
        updated_content,
        branch: @pr_branch
      )

      puts "[AutoChangelog] ✅ Committed changelog update to #{@pr_branch}"
    end

    def fetch_file_info(section)
      file = @client.contents(@repo, path: @changelog_path, ref: @pr_branch)
      decoded_content = Base64.decode64(file[:content])
      lines = decoded_content.lines

      # Look for matching section header
      insert_index = lines.find_index { |line| line.strip.match?(/^#+\s*\[?#{Regexp.escape(section)}\]?/i) }

      # Fallback to beginning of file
      insert_index ||= 0

      {insert_index:, lines:, file_sha: file.sha}
    end
  end
end
