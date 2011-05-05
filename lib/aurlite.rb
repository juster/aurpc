require 'sqlite3'

SQL_PKGINFO = <<'ENDSQL'

SELECT p.pkg_id, a.txt, n.txt,
       p.version,
       p.description
FROM   pkg_name AS n
JOIN   pkg      AS p ON (p.name_id   = n.name_id)
JOIN   author   AS a ON (p.author_id = a.author_id)
WHERE  n.txt = ? ;

ENDSQL

SQL_PKGDEPS = <<'ENDSQL'

SELECT n.txt, d.version
FROM   pkg_dep  AS d
JOIN   pkg_name AS n
ON     (d.name_id = n.name_id)
WHERE  d.pkg_id = ?

ENDSQL

SQL_PKGMAKEDEPS = <<'ENDSQL'

SELECT n.txt, md.version
FROM   pkg_makedep AS md
JOIN   pkg_name    AS n
ON     (md.name_id = n.name_id)
WHERE  md.pkg_id = ?

ENDSQL

SQL_GLOBPKG = <<'ENDSQL'

SELECT n.txt, a.txt, p.version, p.description
FROM   pkg_name AS n
JOIN   pkg      AS p ON (p.name_id   = n.name_id)
JOIN   author   AS a ON (p.author_id = a.author_id)
WHERE  n.txt > ? AND n.txt GLOB ? 

LIMIT 500

ENDSQL

SQL_PKGITER = <<'ENDSQL'

SELECT n.txt, a.txt, p.version, p.description
FROM   pkg_name AS n
JOIN   pkg      AS p ON (p.name_id   = n.name_id)
JOIN   author   AS a ON (p.author_id = a.author_id)
WHERE  n.txt > ?

LIMIT 500

ENDSQL

SQL_AUTHORINFO = <<'ENDSQL'

SELECT a.author_id, a.txt
FROM   author AS a
WHERE  a.txt = ?

ENDSQL

SQL_AUTHORPKGS = <<'ENDSQL'

SELECT n.txt, p.version, p.description
FROM   pkg      AS p
JOIN   pkg_name AS n ON (p.name_id   = n.name_id)
WHERE  p.author_id = ?

ENDSQL

class AURLite
  def initialize ( dbpath )
    @db = SQLite3::Database.new( dbpath )

    @pkginfo     = @db.prepare( SQL_PKGINFO )
    @pkgdeps     = @db.prepare( SQL_PKGDEPS )
    @pkgmakedeps = @db.prepare( SQL_PKGMAKEDEPS )
    @pkgiter     = @db.prepare( SQL_PKGITER )

    @authorinfo  = @db.prepare( SQL_AUTHORINFO )
    @authorpkgs  = @db.prepare( SQL_AUTHORPKGS )

    @globpkg = @db.prepare( SQL_GLOBPKG )
  end

  def lookup_pkg ( pkgname )
    row = @pkginfo.execute( pkgname ).next
    return nil if row.nil? or row[0].nil?

    pkgid = row[0]
    pkg = {
      :author  => row[1],
      :name    => row[2],
      :version => row[3],
      :desc    => row[4],
    }

    tmp = @pkgdeps.execute( pkgid ).collect { |row| row.join "" }
    pkg[:depends] = tmp if tmp.length > 0

    tmp = @pkgmakedeps.execute( pkgid ).collect { |row| row.join "" }
    pkg[:makedepends] = tmp if tmp.length > 0
      
    return pkg
  end

  def _matchrow_hash ( row )
    { :name    => row[0], :author => row[1],
      :version => row[2], :desc   => row[3] }
  end

  def glob_pkg ( globstr, after )
    @globpkg.execute( after, globstr ).collect { |row| _matchrow_hash( row ) }
  end

  def iter_pkgs ( after )
    @pkgiter.execute( after ).collect { |row| _matchrow_hash( row ) }
  end

  def lookup_author ( author )
    arow = @authorinfo.execute( author ).next
    return nil if arow.nil?

    authorid = arow[0]
    apkgs = @authorpkgs.execute( authorid ).collect do |pkgrow|
      { :name => pkgrow[0], :version => pkgrow[1], :desc => pkgrow[2] }
    end

    return { :name => arow[1], :packages => apkgs }
  end
end
