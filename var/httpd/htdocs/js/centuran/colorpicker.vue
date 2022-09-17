<template>
  <div>
    <v-menu ref="menu" eager bottom offset-overflow offset-y
        :close-on-click="true"
        :close-on-content-click="false"
        v-model="show" :content-class="`menu-pointing ${menuClasses}`"
        @input="updateClasses('menu')">
      <template v-slot:activator="{ on, attrs }">
        <span ref="colorDisplay" class="cmt-color-display" 
          :style="style" v-on="on">
        </span>
      </template>
      <v-card class="pa-2" elevation="0">
        <v-color-picker
          v-model="color"
          @input="input ? input.value = color : null"
        ></v-color-picker>
      </v-card>
    </v-menu>
  </div>
</template>

<script>
module.exports = {
  props: {
    color: {
      default: '#ffffff',
    }
  },
  data: function () {
    return {
      input:       null,
      menuClasses: "",
      show:        false,
    }
  },
  computed: {
    style: self => `background-color: ${self.color};`
  },
  methods: {
    initialize: function () {
      var parentNode = this.$el.parentNode;

      this.input = parentNode.querySelector('input[type="text"]');

      if (this.input)
        this.color = this.input.value;
    },
    offset: function (element) {
	    var rect = element.getBoundingClientRect(),
	      scrollLeft = window.pageXOffset || document.documentElement.scrollLeft,
	      scrollTop = window.pageYOffset || document.documentElement.scrollTop;
	    return { top: rect.top + scrollTop, left: rect.left + scrollLeft };
	  },
    updateClasses: function (ref) {
      setTimeout((function () {
        var contentOffsetTop = this.offset(this.$refs[ref].$refs.content).top;
        var displayOffsetTop = this.offset(this.$refs.colorDisplay).top;

        if (contentOffsetTop != 0 && contentOffsetTop < displayOffsetTop)
          this.menuClasses = 'menu-above';
        else
          this.menuClasses = 'menu-below';
      }).bind(this), 100);
    },
  },
  mounted: function () {
    this.$el.parentElement.classList.toggle('cmt-otrs-color-hidden', true);
    this.initialize();
  }
}
</script>

<style>
span.cmt-color-display {
  border-radius: 4px;
  cursor: pointer;
  display: inline-block;
  height: 2em;
  width: 2em;
  vertical-align: middle;
}

.menu-pointing {
  background-color: #fff;
}

.menu-below {
  contain: initial;
  margin-top: 16px;
  overflow: visible;
  /* z-index: 1000 !important; */
}

.menu-below::before {
  color: #fff;
  content: "\0F0360";
  font-family: 'Material Design Icons';
  font-size: 50px;
  height: 30px;
  left: calc(0.893 * var(--font-size-base) - 23.123px);
  line-height: 48px;
  position: absolute;
  text-shadow: 0px 0px 10px rgb(0 0 0 / 65%);
  top: 0;
  transform: translateY(-100%);
  width: 30px;
  /* z-index: auto; */
}

.menu-above {
  contain: initial;
  margin-top: -16px;
  overflow: visible;
  /* z-index: 1000 !important */
}

.menu-above::before {
  bottom: -9px;
  color: #fff;
  content: "\0F035D";
  font-family: 'Material Design Icons';
  font-size: 50px;
  height: 30px;
  left: 0;
  line-height: 48px;
  position: absolute;
  text-shadow: 0px 0px 10px rgb(0 0 0 / 65%);
  width: 30px;
  /* z-index: auto; */
}
</style>
