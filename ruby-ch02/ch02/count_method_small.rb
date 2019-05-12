$: << "lib"
require "numo/narray"
require "numo/linalg/autoloader"
require "common/util"
require "nyaplot"

include Common::Util

text = 'You say goodbye and I say hello.'
corpus, word_to_id, id_to_word = preprocess(text)
vocab_size = id_to_word.size
c = create_co_matrix(corpus, vocab_size, 1)
w = ppmi(c)

# SVD
s, u, v = Numo::Linalg.svd(w)

puts c[0, true].inspect
puts w[0, true].inspect
puts u[0, true].inspect

# plot
plot = Nyaplot::Plot.new
names = []
x = []
y = []
word_to_id.each do |word, word_id|
  x << -u[word_id, 0]
  y << u[word_id, 1]
  names << word
end
df = Nyaplot::DataFrame.new({x: x, y: y, name: names})
sc = plot.add_with_df(df, :scatter, :x, :y)
sc.tooltip_contents([:name])
plot.export_html("plot.html")
