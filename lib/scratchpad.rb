#!/usr/bin/env ruby
# encoding: UTF-8

$:[0] = File.dirname(__FILE__) if ENV["NB_EXEC_EXTEXECUTION_PROCESS_UUID"]

puts "RUBY_VERSION #{RUBY_VERSION}"
if RUBY_VERSION < '1.9.0'
  $KCODE = 'u'
  require 'jcode'
end

require 'ostruct'
require 'date'
require 'time'
require 'rubygems'
require 'sdl4r'

#food = OpenStruct.new(:name => 'french fries', 'comment' => 'eat with bier')
#food.fan = OpenStruct.new(:firstname => 'Homer')
#
#puts SDL4R::dump(:food => food)

puts "SDL4R::supports_unicode_identifiers? " + SDL4R::supports_unicode_identifiers?.to_s

#top = SDL4R::load(<<EOS
#o4 content="xyz" {
#  "123"
#  content 456
#}
#EOS
#)
#
#p top
#
#p SDL4R::load(SDL4R::dump(OpenStruct.new(:a => 123, :values => [], :child => OpenStruct.new)))

#p SDL4R::IDENTIFIER_START_REGEXP
#p ('ま' =~ SDL4R::IDENTIFIER_START_REGEXP)
#
#identifier = 'まName'
#SDL4R::validate_identifier(identifier)
#
#file1 = IO.read('./test/sdl4r/test_basic_types.sdl')
#file2 = IO.read('./test/sdl4r/test_structures.sdl')
#
#start = Time.now
#100.times {
#  SDL4R::read(file1)
#  SDL4R::read(file2)
#}
#puts "read #{Time.now - start}"


file1 = IO.read('E:/dev/FranceQ2/src/franceq2/fq.sdl')
fq = SDL4R::load(file1)



require 'json'


class OpenStruct
  def to_json(*a)
    result = {
      JSON.create_id => self.class.name
    }
    instance_variable_get('@table').each_pair do |var, val|
      result[var] = val
    end
    result.to_json(*a)
  end
end

open("fq.json", "w") do |io|
  io << fq.to_json
end
