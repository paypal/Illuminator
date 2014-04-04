require 'rubygems'
require 'fileutils'
require File.join(File.expand_path(File.dirname(__FILE__)), '/PlistEditor.rb')
####################################################################################################
# ParameterStorage classes allow you to create files with parameters
####################################################################################################

class PLISTStorage
  def initialize
    @parameters = Hash.new
  end

  def addParameterToStorage (name, value)
    unless (name.nil? && value.nil?)
      @parameters[name] = value
    end
  end

  def clearAtPath(path)
    FileUtils.remove_file(path, TRUE)
  end
  def saveToPath(path)
    plistEditor = PlistEditor.new
    plistEditor.setPlistPath(path)
    plistEditor.createAtPath
    @parameters.each  do |key, value|
      plistEditor.addParameter(key, value)
    end
    plistEditor.commitChanges
  end

  def readFromStorageAtPath(path)
    plistStorage = PlistEditor.new
    plistStorage.setPlistPath(path)
    return plistStorage.readFromPath
  end

end

