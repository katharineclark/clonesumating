function CsmInPlaceEditor(ele,url,opts) { 
	Ajax.InPlaceEditor.prototype.enterEditMode=function(){};
	Ajax.InPlaceEditor.prototype.createForm=function(){};
	var editor = new Ajax.InPlaceEditor(ele,url,opts);
	editor.enterEditMode=null;
	editor.createForm=null;
	Object.extend(editor, {
		enterEditMode: function(evt) {
			if (this.saving) return;
			if (this.editing) return;
			this.editing = true;
			this.onEnterEditMode();
			if (this.options.externalControl) {
				Element.hide(this.options.externalControl);
			}
			Element.hide(this.element);
			this.createForm();
			this.element.parentNode.insertBefore(this.form, this.element);
			if (this.options.cancelLink) document.getElementById(this.form.id+'-cancelbutton').onclick = this.onclickCancel.bind(this);
			if (this.options.okButton) document.getElementById(this.form.id+'-okbutton').onclick = this.onSubmit.bind(this);
			if (!this.options.loadTextURL) Field.scrollFreeActivate(this.editField);
			// stop the event to avoid a page refresh in Safari
			if (evt) {
				Event.stop(evt);
			}
			return false;

		},
		createForm: function() {
			this.form = document.createElement("form");
			this.form.id = this.options.formId;
			Element.addClassName(this.form, this.options.formClassName)
			this.form.onsubmit = this.onSubmit.bind(this);

			this.createEditField();

			if (this.options.textarea) {
				var br = document.createElement("br");
				this.form.appendChild(br);
			}

			if (this.options.okButton) {
				okButton = document.createElement("span");
				okButton.innerHTML = _makeButton('smallblue','Save','#','id="'+this.form.id+'-okbutton"');
				this.form.appendChild(okButton);
			}

			if (this.options.cancelLink) {
				var obj = this;
				cancelLink = document.createElement('span');
				cancelLink.innerHTML = _makeButton('smallblue','Cancel','#','id="'+this.form.id+'-cancelbutton"');
				this.form.appendChild(cancelLink);
			}

		},
		onComplete: function(transport) {
			if (this.element.innerHTML.indexOf('<dat>') > -1) {
				var str = this.element.innerHTML.replace(/<.?dat>/,'');
				str = str.replace(/<\/dat>/,'');
				this.element.innerHTML = str;
			}
			this.leaveEditMode();
			this.options.onComplete.bind(this)(transport, this.element);
		}
	});
    editor.onclickListener = editor.enterEditMode.bindAsEventListener(editor);
	if (editor.options.externalControl) {
		Event.stopObserving(editor.element, 'mouseover', editor.mouseoverListener);
		Event.stopObserving(editor.element, 'mouseout', editor.mouseoutListener);
		Event.observe(editor.options.externalControl,'click',editor.onclickListener);
	}
}
