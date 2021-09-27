<!-- TODO: make colors styleable with theme CSS -->
<template>
  <v-switch
    v-model="checkbox.checked"
    :label="label"
    inset
    hide-details
    color="#24408c">
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
  // watch: {
  //   'checked': function (checked) {
  //     this.checkbox.checked = checked;
  //   }
  // },
  methods: {
    initializeFromCheckbox: function () {
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

      // TODO: Handle error when checkbox wasn't found

      this.checkbox.style.display = 'none';
    },
  },
  mounted: function () {
    this.initializeFromCheckbox();
  }
}
</script>

<style>
</style>
