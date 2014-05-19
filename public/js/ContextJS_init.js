$(document).ready(function(){
  context.init({preventDoubleContext: false});
  context.settings({compress: true});
});

context.init({
  fadeSpeed: 100,               // The speed in which the context menu fades in (in milliseconds)
  filter: function ($obj){},    // Function that each finished list element will pass through for extra modification.
  above: 'auto',                // If set to 'auto', menu will appear as a "dropup" if there is not enough room below it. Settings to true will make the menu a popup by default.
  preventDoubleContext: true,   // If set to true, browser-based context menus will not work on contextjs menus.
  compress: false               // If set to true, context menus will have less padding, making them (hopefully) more unobtrusive
});