function findCorrectAnswer(idQuestion, questionType) {
  correctIds = [];
  for (id in data[idQuestion]['answers']) {
    if(data[idQuestion]['answers'][id.toString()]['correct'] == true)
      if (questionType == 0)
        return id.toString();
      else {
        correctIds.push(id.toString());
      } 
  }
  return correctIds;
}

function checkSelectMultiple(x, checkedIds, correctIds) {
  results = [];
  
  $.each(checkedIds, function(index, value){
    if (correctIds.indexOf(value) == -1) {
      results.push(false);
      printResults(value, 0, data[x.toString()]['answers'][value]['explanation'], 0);
    }
    else {
      results.push(true);
      printResults(value, 1, data[x.toString()]['answers'][value]['explanation'], 0);
    }
  });
  
  nCorrects = 0;
  nIncorrects = 0;
  $.each(results, function(index, value){
    if (value == true)
      nCorrects += 1;
    else
      nIncorrects += 1;
  });
  
  userPoints += calculateMark(data[x.toString()], x.toString(), null, 3, nCorrects, nIncorrects);
}

function printResults(id, type, explanation, typeQuestion) {
  if (typeQuestion == 0) {                                        // MultipleChoice and SelectMultiple
    $("br[class=" + id + "br" + "]").detach();
    if (type == 1) {
      if ((explanation == "") || (explanation == null))
        $("div[id ~= " + id + "r" + "]").html("<strong class=correct> " + i18n[language]['questions']['correct'] + "</strong></br>");
      else
        $("div[id ~= " + id + "r" + "]").html("<strong class=correct> " + i18n[language]['questions']['correct'] + " - " + explanation + "</strong></br>");
    }
    else {
      if ((explanation == "") || (explanation == null))
        $("div[id ~= " + id + "r" + "]").html("<strong class=incorrect> " + i18n[language]['questions']['incorrect'] + "</strong></br>");
      else
        $("div[id ~= " + id + "r" + "]").html("<strong class=incorrect> " + i18n[language]['questions']['incorrect'] + " - " + explanation + "</strong></br>");
    }
  }
  else {          // FillIn
    for (r in id) {
      input = $("#" + r.toString());
      if (id[r] == true) {
        input.attr('class', input.attr('class') + ' correct');
      }
      else { 
        if ((id[r] == false) || (id[r] != "n/a")) {
          input.attr('class', input.attr('class') + ' incorrect');
        }
      }
      
      if ((id[r] != true) && (id[r] != false) && (id[r] != "n/a")) {
        if (explanation[id[r].toString()] != null)
          $("div[id ~= " + r.toString() + "r" + "]").html(" <div class=explanation>" + explanation[id[r].toString()] + "</div>");
      }
      else {
        if (explanation[r] != null)
          $("div[id ~= " + r + "r" + "]").html(" <div class=explanation>" + explanation[r] + "</div>");
      }
    }
  }
}

function calculateMark(question, id, result, typeQuestion, numberCorrects, numberIncorrects) {
  stringPoints = i18n[language]['questions']['points'];
  if (typeQuestion == 2) {
    if (result) {
      $("#" + id).append("<strong class=mark> " + question['points'].toFixed(2) + "/" + question['points'].toFixed(2) + " " + stringPoints + "</strong></br></br>");
      
      return parseFloat(question['points']);
    }
    else {
      $("#" + id).append("<strong class=mark> 0.00/" + question['points'].toFixed(2) + " " + stringPoints + "</strong></br></br>");
      
      return parseFloat(0);
    }
  }
  else if (typeQuestion == 1) {
    size = 0;
    for (y in question['answers'])
      if (question['answers'][y]['correct'] == true)
        size += 1;
      
      pointsUser = ((question['points'] / size) * numberCorrects).toFixed(2);
    $("#" + id).append("<strong class=mark> " + pointsUser + "/" + question['points'].toFixed(2) + " " + stringPoints + "</strong></br></br>");
    
    return parseFloat(pointsUser);
  }
  else {
    totalCorrects = 0;
    for (y in question['answers']) {
      if (question['answers'][y]['correct'] == true)
        totalCorrects += 1;
    }
    
    correctAnswerPoints = question['points'] / totalCorrects;
    penalty = correctAnswerPoints * numberIncorrects;
    mark = (correctAnswerPoints * numberCorrects) - penalty;
    
    if (mark < 0)
      mark = 0;
    
    $("#" + id).append("<strong class=mark> " + mark.toFixed(2) + "/" + question['points'].toFixed(2) + " " + stringPoints + "</strong></br></br>");        
    
    return parseFloat(mark);
  }
}

function checkFillin(correctAnswers, userAnswers, distractorAnswers, typeCorrection) {
  correction = {};
  checkedAnswers = {};
  
  if (typeCorrection == 0) {          // Order doesn't matter
    for (u in userAnswers) {
      if (userAnswers[u] != undefined) {    // No empty field
        matchedCorrect = false;
        for (y in correctAnswers) {
          if (checkAnswers[u] == undefined) {
            if ((typeof(correctAnswers[y]) == "string") || (typeof(correctAnswers[y]) == "number")) {    // Answer is a String or a Number
              if (userAnswers[u] == correctAnswers[y]) {
                correction[u] = true;
                checkedAnswers[u] = userAnswers[u];
                matchedCorrect = true;
                break;
              }
            }
            else {  // Answer is a Regexp
              if (XRegExp.exec(userAnswers[u], correctAnswers[y])) {
                correction[u] = true;
                checkedAnswers[u] = userAnswers[u];
                matchedCorrect = true;
                break;
              }
            }
          }
        }
        if (!matchedCorrect)
          correction[u] = false;
      }
      else
        correction[u] = "n/a";
    }
  }
  else {                            // Order matters
    for (u in userAnswers) {
      if (userAnswers[u] != undefined) {
        if ((typeof(correctAnswers[u]) == "string") || (typeof(correctAnswers[u]) == "number")) {
          if (userAnswers[u] == correctAnswers[u])
            correction[u] = true;
          else
            correction[u] = false;
        }
        else {
          if (XRegExp.exec(userAnswers[u], correctAnswers[u]))
            correction[u] = true;
          else
            correction[u] = false;
        }
      }
      else
        correction[u] = "n/a";
    }
  }
  
  if (Object.keys(userAnswers).length == 1) {
    for (u in userAnswers) {
      if (correction[u] == false) {
        for (y in distractorAnswers) {
          if ((typeof(distractorAnswers[y]) == "string") || (typeof(distractorAnswers[y]) == "number")) {
            if (userAnswers[u] == distractorAnswers[y])
              correction[u] = y.toString();
          }
          else {
            if (XRegExp.exec(userAnswers[u], distractorAnswers[y]))
              correction[u] = y.toString();
          }
        }
      }
    }
  }
  return correction;
}

function checkAnswer(x) {
  
  if ($("#" + x.toString() + " strong").length == 0) {
    correct = false;
    answers = $("#" + x.toString() + " input");
    
    if (answers.length != 0) {
      if ((answers.attr('class').match("fillin")) || (answers.attr('class').match("dragdropfi")) || (answers.attr('class').match("dragdropmc"))) {
        correctAnswers = {};
        distractorAnswers = {};
        explanation = {};
        stringAnswer = false;
        flag_js = false;
        
        for (ans in data[x.toString()]['answers']) {
          if (data[x.toString()]['answers'][ans]['correct'] == true) {
            if (data[x.toString()]['answers'][ans]['type'] == "Regexp") {
              string = data[x.toString()]['answers'][ans]['answer_text'].split('/');
              regexp = string[1];
              options = string[2];
              correctAnswers[ans.toString()] = XRegExp(regexp, options);
            }
            else if (data[x.toString()]['answers'][ans]['type'] == "JS") {
              flag_js = true;
            }
            else if (data[x.toString()]['answers'][ans]['type'] == "Hash") {
              key = (Object.keys(data[x.toString()]['answers'][ans]['answer_text'])).join();
              correctAnswers[ans.toString()] = data[x.toString()]['answers'][ans]['answer_text'][key];
            }
            else { // String or Number
              correctAnswers[ans.toString()] = data[x.toString()]['answers'][ans]['answer_text'];
              stringAnswer = true;
            }
          }
          else {
            if (data[x.toString()]['answers'][ans]['type'] == "Regexp") {
              string = data[x.toString()]['answers'][ans]['answer_text'].split('/');
              regexp = string[1];
              options = string[2];
              distractorAnswers[ans.toString()] = XRegExp(regexp, options);
            }
            else if (data[x.toString()]['answers'][ans]['type'] == "JS") {
              //
            }
            else {// String or Number
              distractorAnswers[ans.toString()] = data[x.toString()]['answers'][ans]['answer_text'];
              stringAnswer = true;
            }
          }
          explanation[ans] = data[x.toString()]['answers'][ans]['explanation'];
        }
        
        userAnswers = {};
        for (i = 0; i < answers.length; i++) {
          if (answers[i].value == '')
            userAnswers[answers[i].id.toString()] = undefined;
          else
            if (stringAnswer)
              userAnswers[answers[i].id.toString()] = answers[i].value.toLowerCase();
            else
              userAnswers[answers[i].id.toString()] = answers[i].value;
        }
        
        if (flag_js == false) {
          if (data[x.toString()]['order'] == false)
            results = checkFillin(correctAnswers, userAnswers, distractorAnswers, 0);
          else
            results = checkFillin(correctAnswers, userAnswers, distractorAnswers, 1);
          
          allEmpty = true;
          nCorrects = 0;
          
          for (r in results) {
            if (results[r] == true)
              nCorrects += 1;
            if (results[r] != "n/a")
              allEmpty = false;
          }
          
          if (!allEmpty) {
            printResults(results, null, explanation, 1);
            userPoints += calculateMark(data[x.toString()], x.toString(), null, 1, nCorrects, null);
          }
        }
        else {
          nQuestion = parseInt(x.toString().split('-')[1]) + 1;
          id_answer_js = 'qfi' + nQuestion.toString() + '-1';
          result_function = eval(data[x.toString()]['answers'][id_answer_js]['answer_text']);
          
          values = [];
          ids = {};
          $.each(userAnswers, function(k,v) {
            ids[k] = false;
            values.push(eval(v));
          });
          
          result = result_function.apply(this, values);     // Execution of the function
          
          if (result) {
            $.each(ids, function(k,v) {
              ids[k] = true;
            });
          }
          
          printResults(ids, null, explanation, 1);
          userPoints += calculateMark(data[x.toString()], x.toString(), result, 2, null, null);
        }
      }
      
      else if (answers.attr('class') == "select") {
        idCorrectAnswer = findCorrectAnswer(x.toString(), 0);
        
        if ($("#" + x.toString() + " :checked").size() != 0) {
          if ($("#" + x.toString() + " :checked").attr('id') == idCorrectAnswer) {
            printResults($("#" + x.toString() + " :checked").attr('id'), 1, "", 0);
            correct = true;
          }
          else {
            id = $("#" + x.toString() + " :checked").attr('id');
            printResults(id, 0, data[x.toString()]['answers'][id]['explanation'], 0);
          }
          userPoints += calculateMark(data[x.toString()], x.toString(), correct, 2, null, null);
        }
      }
      
      else if (answers.attr('class') == "check"){
        if ($("#" + x.toString() + " :checked").size() != 0) {
          answers = $("#" + x.toString() + " :checked");
          checkedIds = [];
          
          $.each(answers, function(index, value){
            checkedIds.push(value['id']);
          });
          
          correctIds = [];
          correctIds = findCorrectAnswer(x.toString(), 1);
          checkSelectMultiple(x, checkedIds, correctIds);
        }
      }
    }
    
    else if ($("#" + x.toString() + " div[id^=qddsm").length != 0) {
      answers = $("#" + x.toString() + " div[id^=qddsm");
      userAnswers = {};
      allEmpty = true;
      
      $.each(answers, function(i,v) {
        if (v.value !== undefined)
          allEmpty = false;
      });
      
      if (!allEmpty) {
        for (i = 0; i < answers.length; i++) {
          answer = [];
          for (j = 0; j < answers[i].children.length; j++)
            answer.push(answers[i].children[j].innerText);
          userAnswers[answers[i].id] = answer;
        }
        
        result = checkDragDropSM(x.toString(), userAnswers);
        userPoints += calculateMark(data[x.toString()], x.toString(), result, 2, null, null);
      }
    }
    
    else {  // Textarea
      numAnswer = parseInt(x.split('-')[1]) + 1;
      idAnswer = 'qp' + numAnswer.toString() + '-1';
      
      answer = eval("fn = " + data[x.toString()]['answers'][idAnswer]['answer_text']);    // Teacher's code
      eval(id_textareas[idAnswer]['editor'].getValue());                                  // Student's code
      
      try {
        result = answer.call();
      }
      catch(err) {
        result = false;
      }
      
      userPoints += calculateMark(data[x.toString()], x.toString(), result, 2, null, null);
    }
  }
}

function itemExists(item, userAnswer) {
  for (j = 0; j < userAnswer.length; j++) {
    if (item == userAnswer[j])
      return true;
  }
  return false;
}

function checkDragDropSM(id_question, userAnswers) {
  correctAnswers = {};
  for (x in data[id_question]['answers']) {
    correctAnswers[x] = data[id_question]['answers'][x]['answer_text'];
  }
  
  results = [];
  
  for (x in correctAnswers) {
    correctKeys = correctAnswers[x];
    for (y in correctKeys) {
      item = correctKeys[y];
      if ((typeof(item)) == "object") {
        if (item.length != userAnswers[x].length)         // If there're more or less answers that the number of correct answers
          return false;
        else {
          for (z = 0; z < item.length; z++)
            results.push(itemExists(item[z], userAnswers[x]));
        }
      }
      else if ((typeof(item)) == "string") {
        if (userAnswers[x].length != 1)
          return false;
        else {
          results.push(itemExists(item, userAnswers[x]));
        }
      }
    }
  }
  
  correction = true;
  
  $.each(results, function(i,v) {
    if (v == false)
      correction = false;
  });
  
  return correction;
}

function checkAnswers() {
  for (x in data) {
    checkAnswer(x);
  }
}

function storeAnswers() {
  if(typeof(Storage) !== undefined) {
    tmp = {}
    
    inputText = $('input:text').filter(function() { return $(this).val() != ""; });
    for (i = 0; i < inputText.length; i++) {
      idAnswer = inputText[i].id;
      tmp[idAnswer] = inputText[i].value;
    }
    
    inputRadioCheckBox = $('input:checked');
    for (i = 0; i < inputRadioCheckBox.length; i++) {
      idAnswer = inputRadioCheckBox[i].id;
      nquestion = parseInt(idAnswer.split('-')[0].substr(3)) - 1;
      tmp[idAnswer] = data["question-" + nquestion.toString()]['answers'][idAnswer]['answer_text'];
    }
    
    $.each(id_textareas, function(k,v) {
      tmp[k] = id_textareas[k]['editor'].getValue();
    });
    
    localStorage.setItem(timestamp, JSON.stringify(tmp));
  }
  else {
    alert(i18n[language]['alerts']['noStorage']);
  }
}

function loadAnswers() {
  if ((localStorage.length != 0) && (localStorage[timestamp] !== undefined)) {
    tmp = JSON.parse(localStorage[timestamp]);
    for (x in tmp) {
      if ((x.match(/qfi/)) || (x.match(/qddfi/)) || (x.match(/qddmc/)))
        $("#" + x.toString()).val(tmp[x.toString()]);
      else if (x.match(/qp/))
        id_textareas[x]['editor'].setValue(tmp[x]);
      else
        $("#" + x.toString()).attr('checked', 'checked');
    }
  }
}

function deleteAnswers(all) {
  if (all) {
    localStorage.clear();
    alert(i18n[language]['alerts']['storage']);
  }
  else {
    localStorage.removeItem(timestamp);
    alert(i18n[language]['alerts']['answers']);
  }
}

function showTotalScore() {
  $("#score").html(i18n[language]['questions']['score'] + ": " + userPoints.toFixed(2) + "/" + totalPoints.toFixed(2) + " " + i18n[language]['questions']['points'])
}

function reload() {
  window.location.reload();
}

function changeButton(button, numQuestion) {
  if (button.attr('class').match('success')) {
    button.attr('class', button.attr('class').replace('success', 'danger'));
    button.html(i18n[language]['buttons']['hide']);
    showOrHideAnswer(numQuestion, 1);
  }
  else if (button.attr('class').match('danger')){
    button.attr('class', button.attr('class').replace('danger', 'success'));
    button.html(i18n[language]['buttons']['show']);
    showOrHideAnswer(numQuestion, 0);
  }
}

function clearTextarea() {
  areas = $('textarea');
  $.each(areas, function(i, v) {
    if (v.value.match(/^\s+$/))
      v.value = '';
  });
}

function trimButtons() {
  buttons = $('button');
  $.each(buttons, function(i, v) {
    v.textContent = v.textContent.trim();
  });
}

function showOrHideAnswer(numQuestion, flag) {
  answers = data['question-' + numQuestion.toString()]['answers'];
  typeQuestion = Object.keys(answers)[0].split('-')[0].slice(0, 3);
  numQuestion = (++numQuestion).toString();
  
  if (typeQuestion.match(/^qfi$/)) {
    inputs = $("input[id^=qfi" + numQuestion + "-");
    
    $.each(inputs, function(index, value) {
      if (flag == 1)
        $("input[id=" + value.id).val(answers[value.id]['answer_text']);
      else
        $("input[id=" + value.id).val('');
    });
  }
  else if (typeQuestion.match(/^qmc$/)){
    inputs = $("input[id^=qmc" + numQuestion + "-");
    correct = '';
    
    $.each(answers, function(key, value) {
      if (value['correct'] == true)
        correct = key;
    })
    
    if (flag == 1)
      $("input[id=" + correct).prop('checked', true);
    else
      $("input[id=" + correct).prop('checked', false);
  }
  else {
    inputs = $("input[id^=qsm" + numQuestion + "-");
    corrects = [];
    $.each(answers, function(key, value) {
      if (answers[key]['correct'] == true)
        corrects.push(key);
    }); 
    
    $.each(corrects, function(index, value) {
      if (flag == 1)
        $("input[id=" + value).prop('checked', true);
      else
        $("input[id=" + value).prop('checked', false);
    });
  }
}

$("#submit").click(function() {
  checkAnswers();
  filledAllQuiz = true;
  
  for (x in data) {
    if ($("#" + x.toString() + " strong").length == 0)
      filledAllQuiz = false; 
  }
  if (filledAllQuiz)
    $("#submit").detach();
  
  storeAnswers();
  showTotalScore();
});

$("#reset").click(function() {
  reload();
});

$("#deleteAnswers").click(function() {
  deleteAnswers(false);
  reload();
});

$("#deleteStorage").click(function() {
  deleteAnswers(true);
  reload();
});

$("button[id^=show-answer-q-").click(function() {
  numQuestion = parseInt($(this).attr('id').split('-')[3]);
  changeButton($(this), numQuestion);
});

$("button[id^=q-").click(function() {
  nQuestion = $(this).attr('id').split('-')[1];
  checkAnswer('question-' + nQuestion);
  storeAnswers();
  showTotalScore();
});

$(document).ready(function() {
  loadAnswers();
  clearTextarea();
  trimButtons();
});