module Concerns::AcronymGenerator
  class AcronymGenerator
    def initialize(text, number_of_letters = 3)
      @words = preprocess_text(text)
      @acronym_length = number_of_letters
    end

    def preprocess_text(text)
      text = text.gsub('&', ' N ').gsub(/[^a-zA-Z0-9 ]/, ' ')
      space_splited = text.split(' ')
      camel_case_splited = []
      space_splited.each { |word| camel_case_splited += word.split(/(?=[A-Z])/) }
      if camel_case_splited.length == 1
        single_word = camel_case_splited[0]
        vowel_splited = [single_word[0]]
        vowel_splited += single_word[1..-1].split(/[aeiou]/i).
          delete_if { |word| word == '' }

        if vowel_splited.length == 2
          half_length = (single_word.length / 2).to_i
          return [[single_word[0...half_length]], [single_word[half_length..-1]]].reverse
        end

        return vowel_splited.collect { |word| [word] }.reverse
      end

      camel_case_splited.collect { |word| [word] }.reverse
    end

    def cut(word_array, number_of_letters)
      local_word_array = []
      cut_length = number_of_letters
      word_array.each do |word|
        while cut_length > 0
          local_word_array << word[0...cut_length]
          cut_length -= 1
        end
        cut_length = number_of_letters
      end
      local_word_array.uniq
    end

    def random_cut(word_array, number_of_letters)
      local_word_array = []
      cut_length = number_of_letters
      word_array.each do |word|
        while cut_length > 0
          local_word_array << word[0] + (1...cut_length).
            collect { |i| rand(1..word.length) }.sort.
            collect { |index| word[index] }.join('')
          cut_length -= 1
        end
        cut_length = number_of_letters
      end
      local_word_array.uniq
    end

    def get_initials(random = false, threshold = 99)
      words = []
      @words.each do |sub_word|
        if random
          words << random_cut(sub_word, @acronym_length)
        else
          words << cut(sub_word, @acronym_length)
        end
      end

      words.reverse!
      all_words = words.shift
      words.each do |w|
        all_words = all_words.product(w)
      end

      acronyms = []
      all_words.each do |word|
        acronyms << word.flatten unless stringer(word.flatten).size > threshold
      end

      processed_acronyms = []
      difference = 0
      acronyms.each do |word|
        processed_acronyms << word.join('')[0, @acronym_length].upcase
        if word[0] == @acronym_length
          continue
        elsif @acronym_length - word[0].length != difference
          (2...word.length).each do |index|
            if word[index, word.length].present?
              processed_acronyms << ([word[0]] + word[index, word.length]).
                join('')[0, @acronym_length].upcase
            end
          end

          difference = @acronym_length - word[0].length
        end
      end

      processed_acronyms.reverse.uniq
    end

    def stringer(word_array)
      str = ""
      word_array.each do |word|
        str += word
      end
      str
    end
  end

  def create_initials(model_name, id, name)
    initials_generator = AcronymGenerator.new(name)
    possible_initials = initials_generator.get_initials
    possible_initials.each do |initial|
      if model_name.where(initials: initial).empty?
        model_name.find(id).update_column(:initials, initial)
        return
      end
    end

    (1..5).each do
      possible_initials = initials_generator.get_initials(true)
      possible_initials.each do |initial|
        if model_name.where(initials: initial).empty?
          model_name.find(id).update_column(:initials, initial)
          return
        end
      end
    end

    random_initial = name[0].upcase + ('A'..'Z').to_a.sample(2).join('')
    while model_name.where(initials: random_initial).any?
      random_initial = name[0].upcase + ('A'..'Z').to_a.sample(2).join('')
    end
    model_name.find(id).update_column(:initials, random_initial)
  end
end
