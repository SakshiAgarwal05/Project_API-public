module Constants
  module ConstantsQuestion
    TYPE_OF_QUESTIONS = [
      { label: 'Multiple Choice', value: 'MULTIPLE_CHOICE' },
      { label: 'Checkboxes', value: 'CHECKBOXES' },
      { label: 'Dropdown', value: 'DROPDOWN' },
      { label: 'Multiple Textboxes', value: 'MULTIPLE_TEXTBOXES' },
      { label: 'Single Textbox', value: 'SINGLE_TEXTBOX' },
      { label: 'Comment Box', value: 'COMMENT_BOX' },
      { label: 'Date Time', value: 'DATE_TIME' },
      { label: 'Numerical', value: 'NUMERICAL' },
      { label: 'Text Content', value: 'TEXT_CONTENT' },
      { label: 'File Upload', value: 'FILE_UPLOAD' },
      { label: 'Star Rating', value: 'STAR_RATING' },
      { label: 'Like Indicator', value: 'LIKE_INDICATOR' },
      { label: 'Page Break', value: 'PAGE_BREAK' },
    ].freeze

    RATING_SHAPES = [
      { label: 'Star', value: 'STAR_RATING' },
      { label: 'Smiley', value: 'SMILEY_RATING' },
      { label: 'Heart', value: 'HEART_RATING' },
      { label: 'Thumb', value: 'THUMB_RATING' },
    ].freeze

    OPTIONAL = [
      'PAGE_BREAK', 'TEXT_CONTENT', 'LIKE_INDICATOR', 'STAR_RATING', 'COMMENT_BOX', 'SINGLE_TEXTBOX'
    ].freeze
  end
end
