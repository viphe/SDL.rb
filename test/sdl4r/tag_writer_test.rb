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
  
  require 'test/unit'
  
  require 'sdl4r/tag'  
  require 'sdl4r/tag_writer'
  
  class TagWriterTest < Test::Unit::TestCase
    
    def test_new_default_root
      writer = TagWriter.new
      assert_kind_of Tag, writer.root
      assert_equal "", writer.root.namespace
      assert_equal SDL4R::ROOT_TAG_NAME, writer.root.name
    end
    
    def test_new_given_root
      tag = Tag.new "ns", "tag1"
      writer = TagWriter.new tag
      assert_same tag, writer.root
    end
    
    def test_build_simple_tag
      writer = TagWriter.new
      writer.start_element "tag1"
      writer.attribute "ns", "attr1", 123
      writer.end_element
      
      expected = SDL4R::read(<<-EOS)
      tag1 ns:attr1=123
      EOS
      assert_equal expected, writer.root
    end
    
    def test_build_tags_using_block
      writer = TagWriter.new
      writer.start_element "tag1" do
        writer.attribute "ns", "attr1", 123
      end
      writer.start_element "tag2" do
        writer.attribute "attr2", 123
        writer.attribute "attr3", "plume"
        writer.start_tag "tag3" do
          writer.values(456, 789, nil)
        end
      end
      
      expected = SDL4R::read(<<-EOS)
      tag1 ns:attr1=123
      tag2 attr2=123 attr3="plume" {
        tag3 456 789 null
      }
      EOS
      assert_equal expected, writer.root
    end
  end
end