$:.push File.dirname(__FILE__) + '/lib'
require 'cron2english/version'

Gem::Specification.new do |s|
  s.name = "cron2english"
  s.version = Cron2English::VERSION
  s.date = "2014-01-20"

  s.summary = "Converts a crontab schedule into English text."

  s.authors = ["Paul A. Jungwirth"]
  s.homepage = "http://github.com/pjungwir/cron2english"
  s.email = "pj@illuminatedcomputing.com"

  s.licenses = ["MIT"]

  s.require_paths = ["lib"]
  s.executables = []
  s.files = `git ls-files`.split("\n")
  s.test_files = `git ls-files -- {test,spec,fixtures}/*`.split("\n")

  s.add_development_dependency 'rake'
  s.add_development_dependency 'rspec', '~> 2.4.0'
  s.add_development_dependency 'bundler', '>= 0'

end

