<template>
  <div>
    <v-menu ref="menu" eager bottom offset-overflow offset-y
        :content-class="`menu-pointing ${modeClass}`" @input="updateClasses">
      <template v-slot:activator="{ on, attrs }">
        <input ref="dateInput" type="text" v-model="date.displayed" v-on="on" />
      </template>
      <v-date-picker
        v-model="date.picked"
        color="light-blue"
        :no-title="true"
      ></v-date-picker>
      <!-- TODO: Add "Today" button in default slot -->
    </v-menu>
  </div>
</template>

<script>
module.exports = {
  data: function () {
    return {
      date: {
        value: new Date(),
        displayed: "",
        picked: ""
      },
      modeClass: "",
      selects: {
        day:   null,
        month: null,
        year:  null
      }
    };
  },
  watch: {
    'date.value': function (value) {
      this.date.displayed = this.formatDate(value);
      this.date.picked = this.formatDateAsISO(value);

      this.selects.day.value   = this.date.value.getDate();
      this.selects.month.value = this.date.value.getMonth() + 1;
      this.selects.year.value  = this.date.value.getFullYear();
    },
    'date.picked': function (picked) {
      this.date.value = new Date(picked);
      this.date.displayed = this.formatDate(this.date.value);
    }
  },
  methods: {
    formatDateAsISO: function (date) {
      return date.toISOString().substr(0, 10);
    },
    formatDate: function (date) {
      return this.formatDateAsISO(date);
    },
    initializeFromSelects: function () {
      var parentNode = this.$el.parentNode;
      this.selects.day   = parentNode.querySelector('select[name$="Day"]');
      this.selects.month = parentNode.querySelector('select[name$="Month"]');
      this.selects.year  = parentNode.querySelector('select[name$="Year"]');

      if (this.selects.day)
        this.date.value.setDate(this.selects.day.value);
      if (this.selects.month)
        this.date.value.setMonth(this.selects.month.value-1);
      if (this.selects.year)
        this.date.value.setFullYear(this.selects.year.value);

      this.date.picked = this.formatDateAsISO(this.date.value);
      this.date.displayed = this.formatDate(this.date.value);
    },
    updateClasses: function () {
      setTimeout((function () {
        var content   = this.$refs.menu.$refs.content;
        var dateInput = this.$refs.dateInput;
        
        if (content.offsetTop != 0 && content.offsetTop < dateInput.offsetTop)
          this.modeClass = 'menu-above';
        else
          this.modeClass = 'menu-below';
      }).bind(this), 100);
    }
  },
  mounted: function () {
    this.$el.parentElement.classList.toggle('cmt-otrs-datetime-hidden', true);
    // Remove pieces of text between date and time selects
    this.$el.parentElement.childNodes.forEach(function (node) {
      if (node.nodeType == Node.TEXT_NODE)
        node.parentNode.removeChild(node);
    });

    this.initializeFromSelects();
  }
}
</script>

<style scoped>
</style>

<style>
.menu-below {
  contain: initial;
  margin-top: 16px;
  overflow: visible;
}

.menu-below::before {
  color: #fff;
  content: "\0F0360";
  font-family: 'Material Design Icons';
  font-size: 50px;
  height: 30px;
  left: 0;
  line-height: 48px;
  position: absolute;
  text-shadow: 0px 0px 10px rgb(0 0 0 / 65%);
  top: 0;
  transform: translateY(-100%);
  width: 30px;
}

.menu-above {
  contain: initial;
  margin-top: -16px;
  overflow: visible;
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
}
</style>
