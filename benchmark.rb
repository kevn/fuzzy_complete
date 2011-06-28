$LOAD_PATH.unshift('./lib')
require 'rubygems'
require 'fuzzy_complete'
# c = FuzzyComplete.new(File.readlines('names.txt').map(&:chomp), 'foobar', Redis.new, :protobuf)
# c.logger.level = Logger::WARN
# c.find('user', ARGV[0]).each{|r| puts [r[:highlighted_name], r[:highlighted_permalink], r[:score]].inspect }

require 'benchmark'

people = File.readlines('names.txt').map(&:chomp).map{|line| line.split('|')}

c_yajl   = FuzzyComplete::RedisFind.new(File.readlines('names.txt').map(&:chomp), 'foobar', Redis.new, FuzzyComplete::Codec::Yajl.new)
c_protob = FuzzyComplete::RedisFind.new(File.readlines('names.txt').map(&:chomp), 'foobar', Redis.new, FuzzyComplete::Codec::Protobuf.new)

c_yajl.logger.level = Logger::WARN
c_protob.logger.level = Logger::WARN

puts "Generating query terms"
query_terms = (0..500).to_a.map do |i|
  name, permalink = people[rand(people.size)]
  terms = [name, permalink].compact
  term = terms[rand(terms.size)]
  p0 = rand(term.size)
  len = rand(term.size - p0)
  term[p0, len]
end


Benchmark.bm do |x|
  x.report('yajl     ') do
    system 'ruby clear.rb >/dev/null'
    query_terms.each do |term|
      c_yajl.find('user', term)
    end
  end
  x.report('protobuf ') do
    system 'ruby clear.rb >/dev/null'
    query_terms.each do |term|
      c_protob.find('user', term)
    end
  end
end
