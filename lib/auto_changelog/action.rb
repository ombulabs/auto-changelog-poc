require_relative "github_client"
require_relative "llm"


module AutoChangelog
  class Action
    MAX_LINES_TO_READ = 50
    DEFAULT_CHANGELOG_PATH = "CHANGELOG.md"

    def initialize
      @client ||= GithubClient.new(changelog_path)
      @llm ||= LLM.new
    end

    def run
      raise "The changelog file does not exist." unless changelog_path?

      @client.update_changelog(
        section: entry[:section],
        suggested_entry: entry[:entry],
        mode: mode
      )
    end

    def self.run
      new.run
    end

    private

    def entry
      @llm.generate_entry(pr_info, changelog_content)
    end

    def pr_info
      @client.fetch_pr_info
    end

    def changelog_content
      File.readlines(changelog_path).first(max_lines_to_read).join("\n")
    end

    def changelog_path?
      File.exist?(changelog_path)
    end

    def changelog_path
      ENV["INPUT_CHANGELOG_PATH"] || DEFAULT_CHANGELOG_PATH
    end

    def max_lines_to_read
      ENV["INPUT_MAX_LINES_TO_READ"]&.to_i || MAX_LINES_TO_READ
    end

    def mode
      ENV["INPUT_MODE"]&.strip&.downcase
    end
  end
end
