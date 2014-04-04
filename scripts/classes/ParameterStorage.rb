require 'rubygems'
require 'fileutils'
require 'json'
require File.join(File.expand_path(File.dirname(__FILE__)), '/PlistEditor.rb')
####################################################################################################
# ParameterStorage classes allow you to create files with parameters
####################################################################################################

class BaseStorage

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

end


class PLISTStorage < BaseStorage

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

class JSStorage < BaseStorage

  def saveToPath(path)
    contents = ''
    @parameters.each do |key, value|
      if value.kind_of?(Array) || value.kind_of?(Hash)
        contents = contents + "var #{key}=#{value.to_json};\n"
      else
        contents = contents + "var #{key}='#{value}';\n"
      end
    end
    File.open(path,"w") do |f|
      f.write(contents)
    end
  end
end


class JSONStorage < BaseStorage

  def saveToPath(path)
    contents = @parameters.to_json
    File.open(path,"w") do |f|
      f.write(contents)
    end
  end
end

