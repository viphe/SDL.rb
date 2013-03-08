require 'rake'
require 'rake/clean'
require 'rake/testtask' 
require 'rake/gempackagetask'
require 'rake/packagetask'
require 'rubygems'

lib_dir = File.expand_path('lib')
test_dir = File.expand_path('test')

# Use Hanna as the documentation template if installated,
# otherwise generate with the default RDoc generator.
if USING_HANNA = Gem.required_location("hanna", "hanna/rdoctask.rb")
  require 'hanna/rdoctask'
else
  require 'rake/rdoctask'
end

spec = Gem::Specification.new do |s|
  s.platform = Gem::Platform::RUBY
  s.summary = "Simple Declarative Language for Ruby library"
  s.name = 'sdl4r'

  require File.dirname(__FILE__) + "/lib/sdl4r/sdl4r_version.rb"
  s.version = SDL4R::VERSION

  s.requirements << 'none'
  s.require_path = 'lib'
  s.authors = ['Philippe Vosges', 'Daniel Leuck']
  s.email = 'sdl-users@ikayzo.org'
  s.rubyforge_project = 'sdl4r'
  s.homepage = 'http://sdl4r.rubyforge.org/'
  s.files = FileList['lib/sdl4r.rb', 'lib/sdl4r/**/*.rb', 'bin/*', '[A-Z]*', 'test/**/*', 'doc/**/*'].to_a
  s.test_files = FileList[ 'test/**/*test.rb' ].to_a
  s.description = <<-EOF
    The Simple Declarative Language provides an easy way to describe lists, maps,
    and trees of typed data in a compact, easy to read representation.
    For property files, configuration files, logs, and simple serialization
    requirements, SDL provides a compelling alternative to XML and Properties
    files.
  EOF
end

Rake::GemPackageTask.new(spec) do |pkg|
  pkg.need_zip = true
  pkg.need_tar = true
end

Rake::RDocTask.new do |rd|
  files = ['README', 'LICENSE', 'CHANGELOG', 'lib/**/*.rb', 'doc/**/*.rdoc']
  rd.main = 'README'
  rd.rdoc_files.include(files)
  rd.rdoc_files.exclude("lib/scratchpad.rb")
  rd.rdoc_dir = "doc"
  rd.title = "RDoc: Simple Declarative Language for Ruby"
  rd.options << '--charset' << 'utf-8'
  rd.options << '--line-numbers'
  rd.options << '--inline-source'
end

if Gem.required_location("yard", "yard.rb")
  require 'yard'
  YARD::Rake::YardocTask.new do |t|
    files = FileList.new('README', 'LICENSE', 'CHANGELOG', 'lib/**/*.rb', 'doc/**/*.rdoc')
    files.exclude("lib/scratchpad.rb")
    t.files = files.to_ary
  end
end

Rake::TestTask.new do |t|
  t.test_files = FileList['test/**/*test.rb']
  t.verbose = true
  t.libs = [lib_dir, test_dir]
  t.warning = true
end

# Generates the SDL4R site with Nanoc.
nanoc_compile = task :nanoc_compile do
  puts "The Nanoc tasks might work better from the command line." if ENV["NB_EXEC_EXTEXECUTION_PROCESS_UUID"]
  Dir.chdir("nanoc") {
    system("nanoc", "compile")
  }
end
nanoc_compile.comment = "Builds the site with Nanoc"

if Gem.required_location("ruby-prof", "ruby-prof/task.rb")
  require 'ruby-prof/task'

  RubyProf::ProfileTask.new do |t|
    t.test_files = FileList['test/**/*_prof.rb']
    t.output_dir = "."
    t.printer = :graph_html
    t.min_percent = 1
  end
end