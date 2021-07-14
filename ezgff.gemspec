require_relative 'lib/ezgff/version'

Gem::Specification.new do |spec|
  spec.name          = "ezgff"
  spec.version       = Ezgff::VERSION
  spec.authors       = ["Shuji Shigenobu"]
  spec.email         = ["sshigenobu@gmail.com"]

  spec.summary       = %q{Utilities for GFF3}
  spec.description   = %q{Utilities for GFF3, the genome annotation format. Useful to explore the gene model features.}
  spec.homepage      = "https://github.com/shujishigenobu/ezgff_alpha"
  spec.license       = "MIT"
  spec.required_ruby_version = Gem::Requirement.new(">= 2.3.0")

#  spec.metadata["allowed_push_host"] = "TODO: Set to 'http://mygemserver.com'"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/shujishigenobu/ezgff_alpha"
  spec.metadata["changelog_uri"] = "https://github.com/shujishigenobu/ezgff_alpha"
  # TODO: Put your gem's CHANGELOG.md URL here."

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "sqlite3"
  spec.add_runtime_dependency "bio"
  spec.add_runtime_dependency "thor"
  spec.add_runtime_dependency "color_echo"

end
