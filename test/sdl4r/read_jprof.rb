#!/usr/bin/env ruby -w
# encoding: UTF-8

#--
#
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

require 'rubygems'
require 'jruby-prof'

if RUBY_VERSION < '1.9.0'
  $KCODE = 'u'
  require 'jcode'
end

module SDL4R

  require 'sdl4r'

#  SDL4R::use_datetime = false

  file1 = Pathname.new(File.dirname(__FILE__) + '/test_basic_types.sdl').read
  file2 = Pathname.new(File.dirname(__FILE__) + '/test_structures.sdl').read

  # Do all the loading once
  SDL4R::read(file1)
  SDL4R::read(file2)

  result = JRubyProf.profile {
    100.times {
      SDL4R::read(file1)
      SDL4R::read(file2)
    }
  }

  JRubyProf.print_graph_html(result, "read_jprof_pull.html")

end