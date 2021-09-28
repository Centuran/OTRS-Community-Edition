<!-- TODO: make colors styleable with theme CSS -->
<template>
  <v-switch
    v-model="checked"
    :label="label"
    inset
    hide-details
    color="#24408c"
    @change="checkbox.checked = checked">
  </v-switch>
</template>

<script>
module.exports = {
  props: {
    mode: {
      default: 'date/time',
    }
  },
  data: function () {
    return {
      checkbox: null,
      checked: null,
      label: ''
    };
  },
  methods: {
    initializeFromCheckbox: function (lastTry) {
      var sibling = this.$el.previousElementSibling;
      
      while (sibling) {
        if (sibling.nodeName.match(/^(input|label)$/i)) {
          if (sibling.nodeName.toLowerCase() == 'label') {
            this.checkbox =
              document.querySelector('#' + sibling.getAttribute('for'));
            this.label = sibling.textContent;
            sibling.style.display = 'none';
            break;
          }
          else if (sibling.getAttribute('type') == 'checkbox') {
            this.checkbox = sibling;
            break;
          }
        }

        sibling = sibling.previousElementSibling;
      }

      if (this.checkbox) {
        this.checked = this.checkbox.checked;
        this.checkbox.style.display = 'none';
      }
      else if (!lastTry)
        setTimeout(this.initializeFromCheckbox.bind(this, true), 0);
    },
  },
  mounted: function () {
    this.initializeFromCheckbox();
  }
}
</script>

<style>
</style>
