id_textareas = {};

$("textarea").each(function() { 
  id_textareas[this.id] = {};
  id_textareas[this.id]['id'] = this.id;
  id_textareas[this.id]['height'] = parseInt(this.attributes['4'].value);
  id_textareas[this.id]['width'] = parseInt(this.attributes['5'].value);
});

$.each(id_textareas, function(k,v) {
  id_textareas[k]['editor'] = CodeMirror.fromTextArea(document.getElementById(k), {
    lineNumbers: true,
    viewportMargin: Infinity
  });
  id_textareas[k]['editor'].setSize(id_textareas[k]['height'], id_textareas[k]['width']);
  id_textareas[k]['editor'].setValue('');
});