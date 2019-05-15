$: << "lib"
require "numo/narray"
require "common/util"
require "dataset/ptb"

include Dataset
include Common::Util

window_size = 2
wordvec_size = 100

corpus, word_to_id, id_to_word = load_data(:train)
vocab_size = word_to_id.size

puts 'counting  co-occurrence ...'
c = create_co_matrix(corpus, vocab_size, window_size)

puts 'calculating PPMI ...'
w = ppmi(c, true)

puts 'calculating SVD ...'
# Truncated SVD (fast!)
s, u, v = svd(w, wordvec_size)
# SVD (slow)
#s, u, v = Numo::Linalg.svd(w, job: 'S')
pp [s,u,v]

word_vecs = u[true, :wordvec_size]

querys = ['you', 'year', 'car', 'toyota']
querys.each do |query|
  most_similar(query, word_to_id, id_to_word, word_vecs, 5)
end
