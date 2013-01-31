#!/usr/bin/env ruby -w
# encoding: UTF-8

#--
# Simple Declarative Language (SDL) for Ruby
# Copyright 2005 Ikayzo, inc.
#
# This program is free software. You can distribute or modify it under the
# terms of the GNU Lesser General Public License version 2.1 as published by
# the Free Software Foundation.
#
# This program is distributed AS IS and WITHOUT WARRANTY. OF ANY KIND,
# INCLUDING MERCHANTABILITY OR FITNESS FOR A PARTICULAR PURPOSE.
# See the GNU Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with this program; if not, contact the Free Software Foundation, Inc.,
# 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
#++

# Work-around a bug in NetBeans (http://netbeans.org/bugzilla/show_bug.cgi?id=188653)
if ENV["NB_EXEC_EXTEXECUTION_PROCESS_UUID"]
  $:[0] = File.join(File.dirname(__FILE__),'../../lib')
  $:.unshift(File.join(File.dirname(__FILE__),'../../test'))
end

module SDL4R
  
  require 'stringio'
  require 'pathname'
  require 'test/unit'
  require 'tempfile'
    
  require 'sdl4r/writer'
  
  class WriterTest < Test::Unit::TestCase

    def test_new_default_io
      writer = Writer.new
      assert_kind_of(StringIO, writer.io)
    end
    
    def test_new_with_io
      io = StringIO.new
      writer = Writer.new(io)
      assert_same(io, writer.io)
    end
    
    def test_close
      writer = Writer.new
      assert !writer.io.closed?
      writer.close
      assert writer.io.closed?
    end
    
    def test_new_with_body_and_default_io
      block_writer = nil
      
      writer = Writer.new do |w|
        block_writer = w
      end
      
      assert_same writer, block_writer
      assert writer.io.closed?
    end
    
    def test_new_with_body_and_provided_io
      io = StringIO.new
      block_writer = nil
      
      writer = Writer.new(io) do |w|
        block_writer = w
      end
      
      assert_same writer, block_writer
      assert !writer.io.closed?
    end
    
    def test_empty_file
      writer = Writer.new {}
      assert writer.io.string.empty?
    end
    
    def test_new_with_pathname_and_body
      tempfile = Tempfile.new('sdl_writer_test')
      tempfile.close
      begin
        
        writer = Writer.new(Pathname.new(tempfile.path)) do |w|
          assert !w.io.closed?
        end
        assert writer.io.closed?
        
      ensure
        tempfile.delete
      end
    end
    
    def test_new_with_pathname
      tempfile = Tempfile.new('sdl_writer_test')
      tempfile.close
      begin
        
        writer = Writer.new(Pathname.new(tempfile.path))
        begin
          assert !writer.io.closed?
        ensure
          writer.close
        end
        assert writer.io.closed?
        
      ensure
        tempfile.delete
      end
    end
    
    def test_new_with_string
      s = ""
      writer = Writer.new(s)
      assert !writer.io.closed?
      writer.close
      assert writer.io.closed?
    end
    
    def test_new_with_string_with_body
      s = ""
      writer = Writer.new(s) do |w|
        assert !w.io.closed?
      end
      assert writer.io.closed?
    end
    
    def test_raw_string
      sdl = write_to_string do |w|
        assert_same w, (w << "#" << "xyz" << 1)
      end
      assert_equal "#xyz1", sdl
    end
    
    def test_start_element
      assert_equal "", write_to_string { |w| w.start_element "" }
      assert_equal "el", write_to_string { |w| w.start_element "el" }
      assert_equal "el", write_to_string { |w| w.start_element :el }
      assert_equal "ns:el", write_to_string { |w| w.start_element "ns", "el" }
      assert_equal "ns:el", write_to_string { |w| w.start_element :ns, :el }
      
      write_to_string { |w|
        assert_same w, w.start_element("x")
      }
    end
    
    def test_start_end_body
      assert_equal "{\n}\n", write_to_string { |w|
        assert_same w, w.start_body
        assert_same w, w.end_body
      }
    end
    
    def test_tag_with_sub_tags
      sdl = write_to_string { |w|
        w.start_element "archbishop"
        w.start_body
        w.start_element "bishop"
        w.end_element
        w.end_element
      }
      
      assert_equal_sdl(<<-EOS, sdl)
        archbishop {
          bishop
        }
      EOS
    end
    
    def test_element
      assert_equal_sdl "car", write_to_string { |w|
        assert_same w, w.element("car")
      }
      assert_equal_sdl "vehicle:car", write_to_string { |w| w.element "vehicle", "car" }
      assert_equal_sdl "", write_to_string { |w| w.element "" }
      
      sdl = write_to_string do |w|
        w.element "bishop1"
        w.element "bishop2"
      end
      assert_equal_sdl(<<-EOS, sdl)
        bishop1
        bishop2
      EOS
      
      sdl = write_to_string do |w|
        w.element "archbishop" do
          w.element "bishop1" do
            w.element "priest"
          end
          w.element "bishop2"
          w.element "" do
            w.element "errant_monk"
          end
        end
      end
      assert_equal_sdl(<<-EOS, sdl)
        archbishop {
          bishop1 {
            priest
          }
          bishop2
          {
            errant_monk
          }
        }
      EOS
    end
    
    def test_values
      write_to_string { |w|
        assert_same w, w.value(1)
      }
      assert_equal_sdl "1", write_to_string { |w| w.value(1) }
      assert_equal_sdl "1.5F", write_to_string { |w| w.value(1.5) }
      assert_equal_sdl "null", write_to_string { |w| w.value(nil) }
      assert_equal_sdl '"abc"', write_to_string { |w| w.value("abc") }
      assert_equal_sdl '"abc"', write_to_string { |w| w.values("abc") }
      assert_equal_sdl '"abc" null true', write_to_string { |w| w.value("abc", nil, true) }
      assert_equal_sdl '"abc" null true', write_to_string { |w| w.values("abc", nil, true) }
      
      sdl = write_to_string do |w|
        w.element("car") do
          w.value("moonspeed")
        end
      end
      assert_equal_sdl "car \"moonspeed\"", sdl
      
      sdl = write_to_string do |w|
        w.element("car").value("moonspeed")
      end
      assert_equal_sdl "car\n\"moonspeed\"", sdl
      
      sdl = write_to_string do |w|
        w.value(Date.new(2010, 07, 14))
        w.value(SdlTimeSpan.new(0, 1, 2, 3))
      end
      assert_equal_sdl "2010/07/14 0d:01:02:03", sdl
    end
    
    def test_string_quote_option
      writer = Writer.new(:string_quote => '"').value('abc')
      assert_equal '"abc"', writer.io.string
      
      writer = Writer.new(:string_quote => '`').value('abc')
      assert_equal '`abc`', writer.io.string
      
      assert_raise(ArgumentError) { Writer.new(:string_quote => "'").value('abc') }
    end
    
    def test_attributes
      assert_raise(InvalidOperationError) { Writer.new.attribute("x", 123) }
      
      sdl = write_to_string do |w|
        w.value("cowboys")
        assert_same w, w.attribute("cry", false)
      end
      assert_equal_sdl('"cowboys" cry=false', sdl)
      
      sdl = write_to_string do |w|
        w.element(:pirates) do
          w.attribute(:like, "rum")
          w.attribute("like", "sea")
          w.attribute("afraid", "of", nil)
          w.attribute(:ethics, nil)
        end
      end
      assert_equal_sdl('pirates like="rum" like="sea" afraid:of=null ethics=null', sdl)
    end
    
    def write_to_string
      writer = Writer.new(:indent_text => "  ") do |w|
        yield w
      end
      
      writer.io.string
    end
    private :write_to_string
    
    # A special assertion for SDL text:
    # - removes the convenience indentation of the expected text
    # - removes the trailing end-of-line of the expected or actual texts
    def assert_equal_sdl(expected, actual, message = nil)
      if expected =~ /\A(\s*)/
        convenience_indent = $1
        expected = expected.gsub(/^#{convenience_indent}/, "")
      end
      expected = expected.gsub(/\n\Z/m, "")
      actual = actual.gsub(/\n\Z/m, "")
      assert_equal expected, actual, message
    end
  end
end
