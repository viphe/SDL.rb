# encoding: utf-8

require 'rubygems'
require 'bundler'
begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end
require 'rake'
require 'jeweler'

#-spec = Gem::Specification.new do |s|
#-  s.platform = Gem::Platform::RUBY
#-  s.summary = "Simple Declarative Language for Ruby library"
#-  s.name = 'sdl4r'
#-  s.version = '0.9.7'
#-  s.requirements << 'none'
#-  s.require_path = 'lib'
#-  s.authors = ['Philippe Vosges', 'Daniel Leuck']
#-  s.email = 'sdl-users@ikayzo.org'
#-  s.rubyforge_project = 'sdl4r'
#-  s.homepage = 'http://www.ikayzo.org/confluence/display/SDL/Home'
#-  s.files = FileList['lib/sdl4r.rb', 'lib/sdl4r/**/*.rb', 'bin/*', '[A-Z]*', 'test/**/*', 'doc/**/*'].to_a
#-  s.test_files = FileList[ 'test/**/*test.rb' ].to_a
#-  s.description = <<EOF


Jeweler::Tasks.new do |gem|
  # gem is a Gem::Specification... see http://docs.rubygems.org/read/chapter/20 for more options
  gem.name = "sdl4r"
  gem.homepage = "http://github.com/viphe/SDL.rb"
  gem.license = "LGPL"
  gem.summary = %Q{Simple Declarative Language for Ruby library}
  gem.description = <<EOF
The Simple Declarative Language provides an easy way to describe lists, maps, and trees of typed data in a compact, easy to read representation. For property files, configuration files, logs, and simple serialization requirements, SDL provides a compelling alternative to XML and Properties files.
EOF
  gem.email = "philippe.vosges@gmail.com"
  gem.authors = ["Philippe Vosges"]
  # dependencies defined in Gemfile
end
Jeweler::RubygemsDotOrgTasks.new

require 'rake/testtask'
Rake::TestTask.new(:test) do |test|
  test.libs << 'test'
  test.pattern = 'test/**/*_test.rb'
  test.verbose = true
end

if RUBY_VERSION =~ /^1\.8/
  require 'rcov/rcovtask'
  Rcov::RcovTask.new do |test|
    test.libs << 'test'
    test.pattern = 'test/**/test_*.rb'
    test.verbose = true
    test.rcov_opts << '--exclude "gems/*"'
  end
end

task :default => :test

require 'rdoc/task'
Rake::RDocTask.new do |rdoc|
  version = File.exist?('VERSION') ? File.read('VERSION') : ""

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "sdl4r #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end
