require "openai"
require "json"


module AutoChangelog
  class LLM
    MAX_RETRIES = 3

    def initialize
      @client = OpenAI::Client.new(access_token: ENV["OPENAI_API_KEY"])
    end

    def generate_entry(pr_info, changelog_content)
      retries = 0
      previous_error = nil

      while retries < MAX_RETRIES
        messages = build_messages(pr_info, changelog_content, previous_error)

        response = @client.chat(
          parameters: {
            model: model_name,
            response_format: { type: "json_object" },
            messages: messages,
            temperature: temperature
          }
        )

        entry = response.dig("choices", 0, "message", "content").strip

        begin
          return JSON.parse(entry, symbolize_names: true)
        rescue JSON::ParserError => e
          previous_error = e.message
          retries += 1
        end
      end

      raise "Failed to generate changelog entry after #{MAX_RETRIES} attempts. Last error: #{previous_error}"
    end

    private

    def model_name
      ENV["INPUT_MODEL_NAME"] || "gpt-4o"
    end

    def temperature
      ENV["INPUT_MODEL_TEMPERATURE"]&.to_f || 0.4
    end

    def build_messages(pr_info, changelog_content, error_message)
      base = [
        { role: "system", content: system_prompt },
        { role: "user", content: user_prompt(pr_info, changelog_content) }
      ]

      if error_message
        base << { role: "assistant", content: assistant_prompt(error_message) }
      end
      base
    end

    def system_prompt
      <<~PROMPT
        You are a tool that generates changelog entries from pull requests.
        You must analyze the PR and return the changelog section and the suggested entry to add to the changelog.
        Output ONLY valid JSON in the format: { "section": "...", "entry": "..." }
      PROMPT
    end

    def user_prompt(pr_info, changelog_content)
      <<~PROMPT
        Given the following pull request information and existing changelog content, classify the section and generate a changelog entry.

        PR Title: #{pr_info[:title]}

        PR Description:
        #{pr_info[:body]}

        Files Changed:
        #{pr_info[:files].join("\n")}

        Existing Changelog Content (partial):
        #{changelog_content}

        Determine:
        1. The appropriate section for this PR (e.g., "Features", "Bug Fixes", etc.).
        2. A concise changelog entry that summarizes the changes made in this PR, consistent with the existing style and tone of the changelog.

        Output ONLY valid JSON in the format: { "section": "...", "entry": "..." }
      PROMPT
    end

    def assistant_prompt(error_message)
      <<~PROMPT
        The previous response could not be parsed as valid JSON.
        It failed with an error: #{error_message}
        Return ONLY valid JSON as specified.
      PROMPT
    end
  end
end
