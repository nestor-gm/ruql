function allowDrop(ev) {
  ev.preventDefault();
}

function drag(ev) {
  ev.dataTransfer.setData("Text",ev.target.id);
}

function drop(ev, id, clone) {
  ev.preventDefault();
  var data = ev.dataTransfer.getData("Text");
  
  if (clone)
    ev.target.appendChild(document.getElementById(data).cloneNode(true));
  else
    ev.target.appendChild(document.getElementById(data));
  
  var val = document.getElementById(id);
  val.value = document.getElementById(data).innerHTML;
  
  if (id.match(/qddsm/)) {
    if (!document.getElementsByName(id)[0].value.match(val.value + ","))
      document.getElementsByName(id)[0].value += val.value + ","
  }
}