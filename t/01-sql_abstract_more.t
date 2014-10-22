use strict;
use warnings;
no warnings 'qw';

use SQL::Abstract::More;
use Test::More;

use SQL::Abstract::Test import => [qw/is_same_sql_bind/];

plan tests => 41;
diag( "Testing SQL::Abstract::More $SQL::Abstract::More::VERSION, Perl $], $^X" );



my $sqla = SQL::Abstract::More->new;
my ($sql, @bind, $join);

#----------------------------------------------------------------------
# various forms of select()
#----------------------------------------------------------------------

# old API transmitted to parent
($sql, @bind) = $sqla->select('Foo', 'bar', {bar => {">" => 123}}, ['bar']);
is_same_sql_bind(
  $sql, \@bind,
  "SELECT bar FROM Foo WHERE bar > ? ORDER BY bar", [123],
);

# idem, new API
($sql, @bind) = $sqla->select(
  -columns  => [qw/bar/],
  -from     => 'Foo',
  -where    => {bar => {">" => 123}}, 
  -order_by => ['bar']
);
is_same_sql_bind(
  $sql, \@bind,
  "SELECT bar FROM Foo WHERE bar > ? ORDER BY bar", [123],
);

# -distinct
($sql, @bind) = $sqla->select(
  -columns  => [-DISTINCT => qw/foo bar/],
  -from     => 'Foo',
);
is_same_sql_bind(
  $sql, \@bind,
  "SELECT DISTINCT foo, bar FROM Foo", [],
);

# other minus signs
($sql, @bind) = $sqla->select(
  -columns  => [-DISTINCT => -STRAIGHT_JOIN => qw/foo bar/],
  -from     => 'Foo',
);
is_same_sql_bind(
  $sql, \@bind,
  "SELECT DISTINCT STRAIGHT_JOIN foo, bar FROM Foo", [],
);

($sql, @bind) = $sqla->select(
  -columns  => [-SQL_SMALL_RESULT => qw/foo bar/],
  -from     => 'Foo',
);
is_same_sql_bind(
  $sql, \@bind,
  "SELECT SQL_SMALL_RESULT foo, bar FROM Foo", [],
);

($sql, @bind) = $sqla->select(
  -columns  => ["-/*+ FIRST_ROWS (100) */" => qw/foo bar/],
  -from     => 'Foo',
);
is_same_sql_bind(
  $sql, \@bind,
  "SELECT /*+ FIRST_ROWS (100) */ foo, bar FROM Foo", [],
);


# -join
($sql, @bind) = $sqla->select(
  -from => [-join => qw/Foo fk=pk Bar/]
);
is_same_sql_bind(
  $sql, \@bind,
  "SELECT * FROM Foo INNER JOIN Bar ON Foo.fk=Bar.pk", [],
);

#-order_by
($sql, @bind) = $sqla->select(
  -from     => 'Foo',
  -order_by => [qw/-foo +bar buz/],
);
is_same_sql_bind(
  $sql, \@bind,
  "SELECT * FROM Foo ORDER BY foo DESC, bar ASC, buz", [],
);

#-group_by / -having
($sql, @bind) = $sqla->select(
  -columns  => [qw/foo SUM(bar)|sum_bar/],
  -from     => 'Foo',
  -group_by => [qw/-foo/],
  -having   => {sum_bar => {">" => 10}},
);
is_same_sql_bind(
  $sql, \@bind,
  "SELECT foo, SUM(bar) AS sum_bar FROM Foo GROUP BY foo DESC HAVING sum_bar > ?", [10],
);

#-limit alone
($sql, @bind) = $sqla->select(
  -from     => 'Foo',
  -limit    => 100
);
is_same_sql_bind(
  $sql, \@bind,
  "SELECT * FROM Foo LIMIT ? OFFSET ?", [100, 0],
);

#-limit / -offset
($sql, @bind) = $sqla->select(
  -from     => 'Foo',
  -limit    => 100,
  -offset   => 300,
);
is_same_sql_bind(
  $sql, \@bind,
  "SELECT * FROM Foo LIMIT ? OFFSET ?", [100, 300],
);


#-page_size / page_index
($sql, @bind) = $sqla->select(
  -from       => 'Foo',
  -page_size  => 50,
  -page_index => 2,
);
is_same_sql_bind(
  $sql, \@bind,
  "SELECT * FROM Foo LIMIT ? OFFSET ?", [50, 50],
);


# -for
($sql, @bind) = $sqla->select(
  -from   => 'Foo',
  -for    => "UPDATE",
);
is_same_sql_bind(
  $sql, \@bind,
  "SELECT * FROM Foo FOR UPDATE", [],
);

# -want_details
my $details = $sqla->select(
  -columns      => [         qw/f.col1|c1           b.col2|c2 /],
  -from         => [-join => qw/Foo|f       fk=pk   Bar|b     /],
  -want_details => 1,
);
is_same_sql_bind(
  $details->{sql}, $details->{bind},
  "SELECT f.col1 AS c1, b.col2 AS c2 FROM Foo AS f INNER JOIN Bar AS b ON f.fk=b.pk", [],
);
is_deeply($details->{aliased_tables}, {f => 'Foo', b => 'Bar'});
is_deeply($details->{aliased_columns}, {c1 => 'f.col1', c2 => 'b.col2'});



#----------------------------------------------------------------------
# auxiliary methods : test an instance with standard parameters
#----------------------------------------------------------------------

($sql, @bind) = $sqla->column_alias(qw/Foo f/);
is_same_sql_bind(
  $sql, \@bind,
  "Foo AS f", [],
);

($sql, @bind) = $sqla->column_alias(qw/Foo/);
is_same_sql_bind(
  $sql, \@bind,
  "Foo", [],
);


($sql, @bind) = $sqla->table_alias(qw/Foo f/);
is_same_sql_bind(
  $sql, \@bind,
  "Foo AS f", [],
);

($sql, @bind) = $sqla->limit_offset(123, 456);
is_same_sql_bind(
  $sql, \@bind,
  "LIMIT ? OFFSET ?", [123, 456]
);


$join = $sqla->join(qw[Foo|f =>{fk_A=pk_A,fk_B=pk_B} Bar]);
is_same_sql_bind(
  $join->{sql}, $join->{bind},
  "Foo AS f LEFT OUTER JOIN Bar ON f.fk_A = Bar.pk_A AND f.fk_B = Bar.pk_B", [],
);

$join = $sqla->join(qw[Foo <=>[A<B,C<D] Bar]);
is_same_sql_bind(
  $join->{sql}, $join->{bind},
  "Foo INNER JOIN Bar ON Foo.A < Bar.B OR Foo.C < Bar.D", [],
);


$join = $sqla->join(qw[Foo == Bar]);
is_same_sql_bind(
  $join->{sql}, $join->{bind},
  "Foo NATURAL JOIN Bar", [],
);


$join = $sqla->join(qw[Table1|t1       ab=cd         Table2|t2
                                   <=>{ef>gh,ij<kl}  Table3
                                    =>{t1.mn=op}     Table4]);
is_same_sql_bind(
  $join->{sql}, $join->{bind},
  "Table1 AS t1 INNER JOIN      Table2 AS t2 ON t1.ab=t2.cd
                INNER JOIN      Table3       ON t2.ef>Table3.gh 
                                            AND t2.ij<Table3.kl
                LEFT OUTER JOIN Table4       ON t1.mn=Table4.op",
  [],
);



my $merged = $sqla->merge_conditions(
    {a => 12, b => {">" => 34}}, 
    {b => {"<" => 56}, c => 78},
  );
is_deeply($merged,
          {a => 12, b => [-and => {">" => 34}, {"<" => 56}], c => 78});


#----------------------------------------------------------------------
# test a customized instance
#----------------------------------------------------------------------

$sqla = SQL::Abstract::More->new(table_alias  => '%1$s %2$s',
                                 limit_offset => "LimitXY",
                                 sql_dialect  => "MsAccess");

$join = $sqla->join(qw[Foo|f  =>{fk_A=pk_A,fk_B=pk_B} Bar]);
is_same_sql_bind(
  $join->{sql}, $join->{bind},
  "Foo f LEFT OUTER JOIN (Bar) ON f.fk_A = Bar.pk_A AND f.fk_B = Bar.pk_B", [],
);


($sql, @bind) = $sqla->limit_offset(123, 456);
is_same_sql_bind(
  $sql, \@bind,
  "LIMIT ?, ?", [456, 123]
);


$sqla = SQL::Abstract::More->new(sql_dialect => 'Oracle');
($sql, @bind) = $sqla->select(
  -columns => [qw/col1|c1 col2|c2/],
  -from    => [-join => qw/Foo|f fk=pk Bar|b/],
);
is_same_sql_bind(
  $sql, \@bind,
  "SELECT col1 c1, col2 c2 FROM Foo f INNER JOIN Bar b ON f.fk=b.pk",
  []
);



#----------------------------------------------------------------------
# method redefinition
#----------------------------------------------------------------------

$sqla = SQL::Abstract::More->new(
    limit_offset => sub {
      my ($self, $limit, $offset) = @_;
      defined $limit or die "NO LIMIT!";
      $offset ||= 0;
      my $last = $offset + $limit;
      return ("ROWS ? TO ?", $offset, $last); # ($sql, @bind)
     });


($sql, @bind) = $sqla->limit_offset(123, 456);
is_same_sql_bind(
  $sql, \@bind,
  "ROWS ? TO ?", [456, 579]
);


#----------------------------------------------------------------------
# max_members_IN
#----------------------------------------------------------------------

$sqla = SQL::Abstract::More->new(
  max_members_IN => 10
 );

my @vals = (1 .. 35);
($sql, @bind) = $sqla->where({foo => {-in => \@vals}});

is_same_sql_bind(
  $sql, \@bind,
  ' WHERE ( ( foo IN ( ?, ?, ?, ?, ?, ?, ?, ?, ?, ? ) '
       . ' OR foo IN ( ?, ?, ?, ?, ?, ?, ?, ?, ?, ? ) '
       . ' OR foo IN ( ?, ?, ?, ?, ?, ?, ?, ?, ?, ? ) '
       . ' OR foo IN ( ?, ?, ?, ?, ?, ) ) )',
  [1 .. 35]
);


($sql, @bind) = $sqla->where({foo => {-not_in => \@vals}});
is_same_sql_bind(
  $sql, \@bind,
  ' WHERE ( ( foo NOT IN ( ?, ?, ?, ?, ?, ?, ?, ?, ?, ? ) '
      . ' AND foo NOT IN ( ?, ?, ?, ?, ?, ?, ?, ?, ?, ? ) '
      . ' AND foo NOT IN ( ?, ?, ?, ?, ?, ?, ?, ?, ?, ? ) '
      . ' AND foo NOT IN ( ?, ?, ?, ?, ?, ) ) )',
  [1 .. 35]
);

$sqla = SQL::Abstract::More->new(
  max_members_IN => 3
 );

($sql, @bind) = $sqla->where({foo => {-in     => [1 .. 5]},
                              bar => {-not_in => [6 .. 10]}});
is_same_sql_bind(
  $sql, \@bind,
  ' WHERE (     ( bar NOT IN ( ?, ?, ? ) AND bar NOT IN ( ?, ? ) )'
        . ' AND ( foo IN ( ?, ?, ? ) OR foo IN ( ?, ? ) )  )',
  [6 .. 10, 1 .. 5]
);



#----------------------------------------------------------------------
# insert
#----------------------------------------------------------------------

# usual, hashref syntax
($sql, @bind) = $sqla->insert(
  -into => 'Foo',
  -values => {foo => 1, bar => 2},
);
is_same_sql_bind(
  $sql, \@bind,
  'INSERT INTO Foo(bar, foo) VALUES (?, ?)',
  [2, 1],
);

# arrayref syntax
($sql, @bind) = $sqla->insert(
  -into => 'Foo',
  -values => [1, 2],
);
is_same_sql_bind(
  $sql, \@bind,
  'INSERT INTO Foo VALUES (?, ?)',
  [1, 2],
);

# old API
($sql, @bind) = $sqla->insert('Foo', {foo => 1, bar => 2}); 
is_same_sql_bind(
  $sql, \@bind,
  'INSERT INTO Foo(bar, foo) VALUES (?, ?)',
  [2, 1],
);

($sql, @bind) = eval {$sqla->insert(-foo => 3); };
ok($@, 'unknown arg to insert()');


#----------------------------------------------------------------------
# update
#----------------------------------------------------------------------

# complete syntax
($sql, @bind) = $sqla->update(
  -table => 'Foo',
  -set => {foo => 1, bar => 2},
  -where => {buz => 3},
);
is_same_sql_bind(
  $sql, \@bind,
  'UPDATE Foo SET bar = ?, foo = ? WHERE buz = ?',
  [2, 1, 3],
);

# without where
($sql, @bind) = $sqla->update(
  -table => 'Foo',
  -set => {foo => 1, bar => 2},
);
is_same_sql_bind(
  $sql, \@bind,
  'UPDATE Foo SET bar = ?, foo = ?',
  [2, 1],
);

# old API
($sql, @bind) = $sqla->update('Foo', {foo => 1, bar => 2}, {buz => 3});
is_same_sql_bind(
  $sql, \@bind,
  'UPDATE Foo SET bar = ?, foo = ? WHERE buz = ?',
  [2, 1, 3],
);


#----------------------------------------------------------------------
# delete
#----------------------------------------------------------------------

# complete syntax
($sql, @bind) = $sqla->delete(
  -from => 'Foo',
  -where => {buz => 3},
);
is_same_sql_bind(
  $sql, \@bind,
  'DELETE FROM Foo WHERE buz = ?',
  [3],
);

# old API
($sql, @bind) = $sqla->delete('Foo', {buz => 3});
is_same_sql_bind(
  $sql, \@bind,
  'DELETE FROM Foo WHERE buz = ?',
  [3],
);
