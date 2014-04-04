#!/usr/bin/env ruby
require 'rubygems'
require 'plist'

####################################################################################################
# reads/writes plist at plistPath
####################################################################################################
class PlistEditor

  def initialize
    @plistPath = ''
    @parameters = Hash.new
  end

  def setPlistPath (path)
    @plistPath = path
  end

  def createAtPath
    empty = Hash.new
    Plist::Emit.save_plist(empty, @plistPath)
  end

  def addParameter(parameterName = '',parameterValue = '')
    @parameters[parameterName] = parameterValue
  end

  def readFromPath
    plist = Plist::parse_xml(@plistPath)
    puts plist
    return plist
  end


  def commitChanges
    plist = self.readFromPath
    @parameters.each do |key, value|
      plist[key] = value
    end
    Plist::Emit.save_plist(plist, @plistPath)
  end

end

