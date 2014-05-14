var assert = chai.assert;
if (window.__html__ != undefined) {
  document.body.innerHTML = window.__html__['tests/index.html'];
}

suite('objects defined', function() {
  
  test('check objects defined', function() {
    $.each([data, i18n], function(i,v) {
      assert.isDefined(v, 'defined');
    });
  });
  
});

suite('removing extra spaces in strings', function() {
  
  test('of buttons', function() {
    trimButtons();
    buttons = $('button');
    $.each(buttons, function(i,v) {
      assert.notMatch(v.textContent, /\w+\s{2,}$/, "buttons haven't extra spaces at the end");
    });
  });
  
  test('of textareas', function() {
    clearTextarea()
    areas = $('textarea');
    $.each(areas, function(i, v) {
      assert.match(v.value, '', 'textareas are empty')
    });
  });
  
});

suite('local storage', function() {  
  
  test('delete all localStorage', function() {
    deleteAnswers(true);
    assert.lengthOf(localStorage, 0, 'local storage is empty');
  });
  
  test('delete localStorage of a specific quiz', function() {
    deleteAnswers(false);
    assert.isUndefined(localStorage[timestamp], 'local storage is undefined');
  });
 
});

suite('check if a correct answer has been typed by the user', function() {
  
  test('answer exists', function() {
    assert.isTrue(itemExists(2, [1,2,3]), 'the answer is present');
  });
  
});

suite('validating answers', function() {
  
  test('fill_in answer', function() {
    qfi1_1.value = "link";
    assert.match(qfi1_1.value, data['question-0']['answers']['qfi1-1']['answer_text'], 'is correct');
  });
  
  test('multiple choice answer', function() {
    qmc2_3.setAttribute('checked', true)
    assert.isTrue(qmc2_3.checked, 'is correct');
  });
  
  test('select multiple answer', function() {
    correct_answers = [qsm3_1, qsm3_2, qsm3_3];
    $.each(correct_answers, function(i,v) {
      v.setAttribute('checked', true);
    })
    
    $.each(correct_answers, function(i,v) {
      assert.isTrue(v.checked, 'is correct');
    });
  });
  
  test('true/false answer', function() {
    qmc4_1.setAttribute('checked', true)
    assert.isFalse(qmc4_2.checked, 'is incorrect');
  });
});