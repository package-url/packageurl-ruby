# frozen_string_literal: true

target :lib do
  signature 'sig'

  check 'lib'

  library 'uri'

  configure_code_diagnostics do |config|
    config[Steep::Diagnostic::Ruby::UnsupportedSyntax] = :hint
    config[Steep::Diagnostic::Ruby::MethodDefinitionMissing] = :hint
  end
end

target :test do
  signature 'sig'

  check 'test'

  library 'uri'
end
