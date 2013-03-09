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

def gem_available?(name)
   Gem::Specification.find_by_name(name)
rescue Gem::LoadError
   false
rescue
   Gem.available?(name)
end

lib_dir = File.expand_path('lib')
test_dir = File.expand_path('test')
spec_dir = File.expand_path('spec')


#  s.platform = Gem::Platform::RUBY
#  s.summary = "Simple Declarative Language for Ruby library"
#  s.name = 'sdl4r'
#
#  require File.dirname(__FILE__) + "/lib/sdl4r/sdl4r_version.rb"
#  s.version = SDL4R::VERSION
#
#  s.requirements << 'none'
#  s.require_path = 'lib'
#  s.authors = ['Philippe Vosges', 'Daniel Leuck']
#  s.email = 'sdl-users@ikayzo.org'
#  s.rubyforge_project = 'sdl4r'
#  s.homepage = 'http://sdl4r.rubyforge.org/'
#  s.files = FileList['lib/sdl4r.rb', 'lib/sdl4r/**/*.rb', 'bin/*', '[A-Z]*', 'test/**/*', 'doc/**/*'].to_a
#  s.test_files = FileList[ 'test/**/*test.rb' ].to_a
#  s.description = <<-EOF

Jeweler::Tasks.new do |gem|
  # gem is a Gem::Specification... see http://docs.rubygems.org/read/chapter/20 for more options
  gem.name = "sdl4r"
  gem.homepage = "http://github.com/viphe/SDL.rb"
  gem.license = "LGPL"
  gem.summary = %Q{Simple Declarative Language for Ruby library}
  gem.description = <<-EOF
    The Simple Declarative Language provides an easy way to describe lists, maps,
    and trees of typed data in a compact, easy to read representation.
    For property files, configuration files, logs, and simple serialization
    requirements, SDL provides a compelling alternative to XML and Properties
    files.
EOF
  gem.email = "philippe.vosges@gmail.com"
  gem.authors = ["Philippe Vosges"]
  # dependencies defined in Gemfile
end
Jeweler::RubygemsDotOrgTasks.new


documented_src_files = ['lib/**/*.rb']
documented_doc_files = ['README.rdoc', 'LICENSE', 'CHANGELOG.rdoc']

require 'rdoc/task'
Rake::RDocTask.new do |rd|
  
  require "#{lib_dir}/sdl4r/sdl4r_version"
  version =  SDL4R::VERSION
  
  rd.main = documented_doc_files[0]
  rd.rdoc_files.include(documented_src_files + documented_doc_files)
  rd.rdoc_dir = 'doc'
  rd.title = "RDoc: Simple Declarative Language for Ruby (v#{version})"
  rd.template = 'direct' # lighter template used on railsapi.com
  rd.options << '--charset' << 'utf-8'
  rd.options << '--line-numbers'
end

if gem_available? 'yard'
  require 'yard'
  YARD::Rake::YardocTask.new do |t|
    files = FileList.new(*(documented_src_files + ['-'] + documented_doc_files))
    t.files = files.to_ary
  end
end

require 'rake/testtask'
Rake::TestTask.new(:test) do |test|
  test.libs << 'test'
  test.pattern = 'test/**/*_test.rb'
  test.verbose = true
  test.warning = true
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

# Generates the SDL4R site with Nanoc.
nanoc_compile = task :nanoc_compile do
  puts "The Nanoc tasks might work better from the command line." if ENV["NB_EXEC_EXTEXECUTION_PROCESS_UUID"]
  Dir.chdir("nanoc") {
    system("nanoc", "compile")
  }
end
nanoc_compile.comment = "Builds the site with Nanoc"


if gem_available? 'ruby-prof'
  require 'ruby-prof/task'

  RubyProf::ProfileTask.new do |t|
    t.test_files = FileList['test/**/*_prof.rb']
    t.output_dir = "."
    t.printer = :graph_html
    t.min_percent = 1
  end
end
