require 'numo/narray'
require 'numo/linalg/autoloader'

module Common
  module Util
    def preprocess(text)
      text = text.downcase
      text = text.gsub('.', ' .')
      words = text.split(' ')

      word_to_id = {}
      id_to_word = {}
      words.each do |word|
        unless word_to_id[word]
          new_id = word_to_id.size
          word_to_id[word] = new_id
          id_to_word[new_id] = word
        end
      end
      corpus = Numo::Int32[*words.map{|w| word_to_id[w]}]

      return corpus, word_to_id, id_to_word
    end
    module_function :preprocess

    # コサイン類似度の算出
    #
    # @param x ベクトル
    # @param y ベクトル
    # @param eps ”0割り”防止のための微小値
    # @return
    def cos_similarity(x, y, eps=1e-8)
      nx = x / (Numo::NMath.sqrt((x ** 2).sum) + eps)
      ny = y / (Numo::NMath.sqrt((y ** 2).sum) + eps)
      return nx.dot(ny)
    end
    module_function :cos_similarity


    # 共起行列の作成
    #
    # @param corpus コーパス（単語IDのリスト）
    # @param vocab_size 語彙数
    # @param window_size ウィンドウサイズ（ウィンドウサイズが1のときは、単語の左右1単語がコンテキスト）
    # @return 共起行列
    def create_co_matrix(corpus, vocab_size, window_size=1)
      corpus_size = corpus.size
      co_matrix = Numo::Int32.zeros(vocab_size, vocab_size)

      corpus.each_with_index do |word_id, idx|
        (1 .. window_size).each do |i|
          left_idx = idx - i
          right_idx = idx + i

          if left_idx >= 0
            left_word_id = corpus[left_idx]
            co_matrix[word_id, left_word_id] += 1
          end

          if right_idx < corpus_size
            right_word_id = corpus[right_idx]
            co_matrix[word_id, right_word_id] += 1
          end
        end
      end
      return co_matrix
    end
    module_function :create_co_matrix

    # 類似単語の検索
    #
    # @param query クエリ（テキスト）
    # @param word_to_id 単語から単語IDへのディクショナリ
    # @param id_to_word 単語IDから単語へのディクショナリ
    # @param word_matrix 単語ベクトルをまとめた行列。各行に対応する単語のベクトルが格納されていることを想定する
    # @param top 上位何位まで表示するか
    def most_similar(query, word_to_id, id_to_word, word_matrix, top=5)
      unless word_to_id[query]
        printf('%s is not found', query)
        return
      end
      print("\n[query] " +  query + "\n")
      query_id = word_to_id[query]
      query_vec = word_matrix[query_id, true]

      vocab_size = id_to_word.size

      similarity = Numo::SFloat.zeros(vocab_size)
      (0 ... vocab_size).each do |i|
        similarity[i] = cos_similarity(word_matrix[i,true], query_vec)
      end
      count = 0
      (-1 * similarity).sort_index.each do |i|
        if id_to_word[i] == query
          next
        end
        printf(" %s: %s\n" , id_to_word[i], similarity[i])

        count += 1
        if count >= top
          return
        end
      end
    end
    module_function :most_similar

    # PPMI（正の相互情報量）の作成
    #
    # @param c 共起行列
    # @param verbose 進行状況を出力するかどうか
    # @return
    def ppmi(c, verbose=false, eps = 1e-8)

      m = Numo::SFloat.cast(c).new_zeros
      n = c.sum
      s = c.sum(axis: 0)
      total = c.shape[0] * c.shape[1]
      cnt = 0

      c.shape[0].times do |i|
        c.shape[1].times do |j|
          pmi = Numo::NMath.log2(Numo::SFloat.cast(c[i, j] * n) / (s[j]*s[i]) + eps)
          m[i, j] = (pmi.to_f < 0) ? 0 : pmi

          if verbose
            cnt += 1
            if cnt % (total/100) == 0
              printf("%.1f%% done\n" , 100*cnt/total)
            end
          end
        end
      end
      return m
    end
    module_function :ppmi

    # https://yoshoku.hatenablog.com/entry/2019/01/06/193347
    # a: 入力行列
    # k: 大きい方から得る特異値・特異ベクトルの数
    def svd(a, k)
      # 入力行列の大きさを得る。
      n_rows, = a.shape

      # 対称行列を計算する。
      b = a.dot(a.transpose)

      # 対称行列を固有値の範囲を指定して固有値分解する。
      # Numo::Linalg.eighメソッドでは固有値は昇順に並ぶ。
      # 大きい方から得られるように値の範囲の指定に注意する。
      vals_range = (n_rows - k)...n_rows
      evals, evecs =  Numo::Linalg.eigh(b, vals_range: vals_range)

      # 固有値・固有ベクトルから特異値・左右の特異ベクトルを求める。
      # reverseメソッドで降順にしている。
      s = Numo::NMath.sqrt(evals.reverse.dup)
      u = evecs.reverse(1).dup
      vt = (1.0 / s).diag.dot(u.transpose).dot(a)

      [s, u, vt]
    end
    module_function :svd
  end
end

if __FILE__ == $0
  include Common::Util
  text = 'You say goodbye and I say hello.'
  corpus, word_to_id, id_to_word = preprocess(text)
  vocab_size = word_to_id.size
  c = create_co_matrix(corpus, vocab_size)
  c0 = c[word_to_id['you'], true]
  c1 = c[word_to_id['i'], true]
  pp cos_similarity(c0, c1)
  puts "-"*80
  most_similar('you', word_to_id, id_to_word, c, 5)
  puts "-"*80
  w = ppmi(c)
  pp w
  require "numo/linalg/autoloader"
  s, u, vt = Numo::Linalg.svd(w)
  pp [:SVD, s, u, vt]
  pp [c[0,true], w[0,true], u[0,true]]
end
