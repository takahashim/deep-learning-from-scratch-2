$: << ".."
require "numo/narray"
require "open-uri"

module Dataset

  URL_BASE = 'https://raw.githubusercontent.com/tomsercu/lstm/master/data/'
  KEY_FILE = {
    train: 'ptb.train.txt',
    test: 'ptb.test.txt',
    valid: 'ptb.valid.txt'
  }

  SAVE_FILE = {
    train: 'ptb.train.dump',
    test: 'ptb.test.dump',
    valid: 'ptb.valid.dump'
  }

  VOCAB_FILE = 'ptb.vocab.dump'

  DATASET_DIR = File.dirname(__FILE__)

  # @param data_type データの種類：'train' or 'test' or 'valid (val)'
  # @return
  def load_data(data_type=:train)

    if data_type == :val
      data_type = :valid
    end
    save_path = DATASET_DIR + '/' + SAVE_FILE[data_type]

    word_to_id, id_to_word = load_vocab()

    if File.exists? save_path
      corpus = Marshal.load(File.binread(save_path))
      return corpus, word_to_id, id_to_word
    end

    file_name = KEY_FILE[data_type]
    file_path = DATASET_DIR + '/' + file_name
    download(file_name)

    words = File.read(file_path).gsub("\n", '<eos>').strip().split()
    corpus = Numo::Int32[words.map{|w| word_to_id[w]}]

    File.binwrite(save_path, Marshal.dump(corpus))
    return corpus, word_to_id, id_to_word
  end
  module_function :load_data

  def load_vocab()
    vocab_path = DATASET_DIR + '/' + VOCAB_FILE

    word_to_id = {}
    id_to_word = {}

    if File.exists?(vocab_path)
      File.open(vocab_path, 'rb') do |f|
        word_to_id, id_to_word = Marshal.load(f)
      end
      return word_to_id, id_to_word
    end

    data_type = :train
    file_name = KEY_FILE[data_type]
    file_path = DATASET_DIR + '/' + file_name

    download(file_name)

    words = File.read(file_path).gsub("\n", '<eos>').strip().split()

    words.each do |word|
      unless word_to_id[word]
        tmp_id = word_to_id.size
        word_to_id[word] = tmp_id
        id_to_word[tmp_id] = word
      end
    end
    File.open(vocab_path, 'wb') do |f|
      Marshal.dump([word_to_id, id_to_word], f)
    end

    return word_to_id, id_to_word
  end
  module_function :load_vocab

  def download(file_name)
    file_path = DATASET_DIR + '/' + file_name
    if File.exists?(file_path)
      return
    end
    print('Downloading ' + file_name + ' ... ')

    open(URL_BASE + file_name) do |f|
      File.write(file_path, f.read)
    end
    print 'Done'
  end
  module_function :download

end

if __FILE__ == $0
  [:train, :val, :test].each do |data_type|
    Dataset.load_data(data_type)
  end
end
