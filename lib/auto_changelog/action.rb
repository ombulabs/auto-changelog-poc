require_relative "github_client"
require_relative "llm"


module AutoChangelog
  class Action
    def self.run
      client = GithubClient.new
      llm = LLM.new
      changelog_content = File.read("CHANGELOG.md") if File.exist?("CHANGELOG.md")

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
