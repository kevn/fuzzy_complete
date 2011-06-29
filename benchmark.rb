$LOAD_PATH.unshift('./lib')
require 'rubygems'
require 'fuzzy_complete'


# c = FuzzyComplete::RedisFind.new(File.readlines('names.txt').map(&:chomp), 'foobar', Redis.new, FuzzyComplete::Codec::Yajl.new)
# c.logger.level = Logger::WARN
# c.find('user', ARGV[0]).each{|r| puts [r[:highlighted_name], r[:highlighted_permalink], r[:score]].inspect }

require 'benchmark'

people = File.readlines('names.txt').map(&:chomp).map{|line| line.split('|')}

c_yajl   = FuzzyComplete::RedisFind.new(File.readlines('names.txt').map(&:chomp), 'foobar', Redis.new, FuzzyComplete::Codec::Yajl.new)
c_msgpack   = FuzzyComplete::RedisFind.new(File.readlines('names.txt').map(&:chomp), 'foobar', Redis.new, FuzzyComplete::Codec::Msgpack.new)

c_yajl.logger.level = Logger::WARN
c_msgpack.logger.level = Logger::WARN

puts "Generating query terms"
query_terms = (0..10_000).to_a.map do |i|
  name, permalink = people[rand(people.size)]
  terms = [name, permalink].compact
  term = terms[rand(terms.size)]
  p0 = rand(term.size)
  len = rand(term.size - p0)
  term[p0, len]
end

puts "Yajl"
Benchmark.bm do |x|
  x.report('prime     ') do
    system 'ruby clear.rb >/dev/null'
    query_terms.each do |term|
      c_yajl.find('user', term)
    end
  end
  x.report('cached   ') do
    query_terms.each do |term|
      c_yajl.find('user', term)
    end
  end
end

puts "Msgpack"
Benchmark.bm do |x|
  x.report('prime     ') do
    system 'ruby clear.rb >/dev/null'
    query_terms.each do |term|
      c_msgpack.find('user', term)
    end
  end
  x.report('cached   ') do
    query_terms.each do |term|
      c_msgpack.find('user', term)
    end
  end
end
