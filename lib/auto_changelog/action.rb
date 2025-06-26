require_relative "github_client"
require_relative "llm"


module AutoChangelog
  class Action
    DEFAULT_CHANGELOG_PATH = "CHANGELOG.md"

    def self.run
      changelog_path = ENV["INPUT_CHANGELOG_PATH"] || DEFAULT_CHANGELOG_PATH
      raise "The changelog file does not exist." unless File.exist?(changelog_path)

      client = GithubClient.new(changelog_path)
      llm = LLM.new
      changelog_content = File.read(changelog_path)

      pr_info = client.fetch_pr_info
      entry = llm.generate_entry(pr_info, changelog_content)
      client.update_changelog(
        section: entry[:section],
        suggested_entry: entry[:entry],
        mode: ENV["INPUT_MODE"]&.strip&.downcase
      )
    end
  end
end
