require 'sinatra'
require 'erb'
require 'json/ext'

APPDIR  = File.dirname( __FILE__ )
BASEURL = 'http://juster.us/aurpc'

$:.push( APPDIR + '/lib' )
require 'aurlite'

STATICDIR  = APPDIR + '/../static'
DB_PATH    = APPDIR + '/../var/aurlite.db'

MIN_SECS  = 60
HOUR_SECS = MIN_SECS  * 60
DAY_SECS  = HOUR_SECS * 24
RESULTS_LIMIT = 500

set :public, STATICDIR

$AURDB = AURLite.new( DB_PATH )

def timediff_str ( oldtime )
  mdiff = Time.now - oldtime
  diffstr = ""

  if mdiff >= DAY_SECS then
    mdiff = (mdiff / DAY_SECS).to_i
    diffstr = "#{mdiff} day"
  elsif mdiff >= HOUR_SECS then
    mdiff = (mdiff / HOUR_SECS).to_i
    diffstr = "#{mdiff} hour"
  else
    mdiff = (mdiff / MIN_SECS).to_i
    diffstr = "#{mdiff} min"
  end

  diffstr << 's' if mdiff > 1
  return diffstr
end

def next_url ( routepath, after )
  url = BASEURL + routepath
  if after and not after.empty? then
    return url + "?after=" + after
  else
    return url
  end
end

def package_url ( pkgname )
  BASEURL + "/packages/#{pkgname}"
end

def author_url ( author )
  BASEURL + "/authors/#{author}"
end

def pkg_matches ( pkgs )
  pkgs.each do |pkg|
    pkg[:author_url] = author_url ( pkg[:author] )
    pkg[:url]        = package_url( pkg[:name]   )
  end

  matchdata = { :matches => pkgs }
  matchdata[:next_url] =
    if pkgs.length == RESULTS_LIMIT then
      next_url( request.path, pkgs[-1][:name] )
    else
      nil
    end
  return matchdata
end

def author_matches ( anames )
  amatches = anames.collect do |aname|
    { :name => aname, :url => author_url( aname ) }
  end

  matchdata = { :matches => amatches }
  matchdata[:next_url] = if amatches.length == RESULTS_LIMIT then
                           next_url( request.path, anames[-1] )
                         else nil end
  return matchdata
end

def find_pkg_glob ( glob )
  after = params[:after] || ""
  pkgs  = $AURDB.glob_pkg( glob, after )
  halt 404, "No matches found" unless pkgs.length > 0

  return JSON.generate pkg_matches( pkgs )
end

get '/' do
  size_of = {}
  %W{ xz gz bz2 }.each do |ext|
    path = STATICDIR + "/aurlite.db." + ext
    size_of[ext] =
      begin
        mbs = File.stat( path ).size.to_f / (1024 ** 2);
        sprintf '%0.2f', mbs
      rescue Errno::ENOENT then "-999" end
  end

  erb :index, :locals => {
    :download_sizes => size_of,
    :freshness      => timediff_str( File.stat( DB_PATH ).mtime )
  }
end

get '/packages/:name' do |name|
  return find_pkg_glob( name ) if name =~ /[*]/

  pkginfo = $AURDB.lookup_pkg( name )
  halt 404, "#{name} was not found" unless pkginfo

  pkginfo[:author_url] = author_url( pkginfo[:author] )
  JSON.generate pkginfo
end

get '/packages' do
  after = params[:after] || ""
  pkgs  = $AURDB.iter_pkgs( after )
  JSON.generate pkg_matches( pkgs )
end

get '/authors/:name' do |name|
  authorinfo = $AURDB.lookup_author( name )
  halt 404, "#{name} was not found" unless authorinfo

  authorinfo[:packages].each { |pkg| pkg[:url] = package_url( pkg[:name] ) }
  JSON.generate authorinfo
end

get '/authors' do
  authors = $AURDB.authors_iter( params[:after] || %Q{} )
  halt 404, 'No matches found' if authors.empty?
  JSON.generate author_matches( authors )
end
