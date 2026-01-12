# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Base Translator" do
  let(:task) { I18n::Tasks::BaseTask.new }

  # Create a fake translator that raises for html slices
  let(:translator_class) do
    Class.new(I18n::Tasks::Translators::BaseTranslator) do
      def translate_values(list, **options)
        if options[:html]
          raise StandardError, "html translation failure"
        end

        # return translated values simply by appending `-es` for testing
        list.map { |v| "#{v}-es" }
      end

      def options_for_translate_values(from:, to:, **options)
        options.merge(from: from, to: to)
      end

      def options_for_html
        {html: true}
      end

      def options_for_plain
        {html: false}
      end

      def no_results_error_message
        "no results"
      end
    end
  end

  it "preserves successful translations when a subsequent slice fails" do
    translator = translator_class.new(task)

    list = [
      ["common.plain", "Hello"],
      ["common.html.html", "<b>Hi</b>"]
    ]

    result = translator.send(:translate_pairs, list, from: "en", to: "es")

    # Find translated plain key
    plain = result.assoc("common.plain")
    expect(plain).not_to be_nil
    expect(plain.last).to eq("Hello-es")

    # HTML slice should have been left untranslated due to simulated failure
    html = result.assoc("common.html.html")
    expect(html).not_to be_nil
    expect(html.last).to eq("<b>Hi</b>")
  end

  context "with parallelize: 2" do
    before do
      allow(task).to receive(:translation_config).and_return({parallelize: 2})
    end

    it "translates correctly with multiple threads" do
      translator = translator_class.new(task)

      list = [
        ["key1", "One"],
        ["key2", "Two"],
        ["key3", "Three"],
        ["key4", "Four"]
      ]

      result = translator.send(:translate_pairs, list, from: "en", to: "es")

      expect(result.assoc("key1").last).to eq("One-es")
      expect(result.assoc("key2").last).to eq("Two-es")
      expect(result.assoc("key3").last).to eq("Three-es")
      expect(result.assoc("key4").last).to eq("Four-es")
    end

    it "preserves key order with parallel execution" do
      translator = translator_class.new(task)

      list = (1..10).map { |i| ["key#{i}", "Value#{i}"] }

      result = translator.send(:translate_pairs, list, from: "en", to: "es")

      expect(result.map(&:first)).to eq((1..10).map { |i| "key#{i}" })
    end
  end
end
