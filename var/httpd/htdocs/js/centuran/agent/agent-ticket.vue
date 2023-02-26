<template>
  <v-container fluid>
    <v-row>
      <v-col cols="12" class="pt-0 px-0">

    <div id="cmt-ticket-timeline" class="WidgetSimple">
      <div class="Header">
        <h2>{{ Core.Language.Translate('Ticket Timeline') }}</h2>
      </div>
      <div class="Content">

        <v-btn-toggle
          v-model="timelineOrder"
          rounded
        >
          <v-btn
            icon
            value="descending"
          >
            <v-icon>mdi-sort-clock-descending</v-icon>
          </v-btn>
        
          <v-btn
            icon
            value="ascending"
          >
            <v-icon>mdi-sort-clock-ascending</v-icon>
          </v-btn>
        </v-btn-toggle>

        <v-timeline
          align-top
          dense
          light
        >
          <v-timeline-item
            v-for="(item, i) in timelineItems"
            :key="i"
            :large="item.article != null"
            light
            class="pt-6 mb-2"
          >
            <template v-slot:icon>
              <v-avatar v-if="item.article">
                <img :src="item.article.gravatarUrl"/>
                
                <v-icon
                  :title="item.title"
                >
                  {{ `mdi-${item.icon}` }}
                </v-icon>
              </v-avatar>
              <v-icon
                v-else
                :title="item.title"
              >
                {{ `mdi-${item.icon}` }}
              </v-icon>
            </template>

            <div class="item-date pl-4 text--secondary">
              <span class="font-weight-medium">

              </span>
              <span class="date text--disabled ml-4">
                {{ item.dateTimeRelative }}
              </span>
            </div>

            <v-card 
              v-if="item.article"
              elevation="2"
              :ripple="false"
              :link="false"
              @click="(event) => { if (!item.article.expanded) item.article.expanded = true; event.stopPropagation(); }"
              :class="item.article.senderType == 'customer' ? 'customer' : ''"
            >
              <v-card-text>
                <div class="title mb-4 font-weight-medium text--primary">
                  {{  }}
                </div>

                <div
                  v-if="item.article.content"
                  class="content"
                >
                  <div v-html="item.article.content"></div>
                </div>
              </v-card-text>
              
              <v-card-actions>
                <!-- Mark/unmark as important -->
                <v-btn
                  icon
                  :data-article-id="item.article.id"
                  @click="item.article.flagAsImportantLink.click()"
                >
                  <v-icon v-if="!item.article.flags.important">
                    mdi-alert
                  </v-icon>
                  <v-icon v-else>
                    mdi-alert-remove
                  </v-icon>
                </v-btn>

                <!-- Print -->
                <v-btn
                  icon
                  :data-article-id="item.article.id"
                  @click="item.article.printLink.click()"
                >
                  <v-icon>mdi-printer</v-icon>
                </v-btn>

                <v-btn
                  icon
                  :data-article-id="item.article.id"
                  @click.stop="function (a) { clickedReplyBtn = a.currentTarget; replyTemplates = item.article.replyTemplates; articleReplyDialog = true; }"
                >
                  <v-icon>mdi-reply</v-icon>
                </v-btn>
              </v-card-actions>
            </v-card>

            <div
              v-else
            >
              {{ item.title }}
            </div>

          </v-timeline-item>
        </v-timeline>

      </div>
    </div>

      </v-col>
    </v-row>

    <div id="cmt-reply-selection">
      <v-card
        height="340px"
      >
        <v-card-text>
          <p>
            {{ Core.Language.Translate('Select response template:') }}
          </p>
          <v-autocomplete
            ref="reply-selection-autocomplete"
            :items="replyTemplates"
            item-text="name"
            item-value="value"
            elevation="0"
            autofocus
            :auto-select-first="true"
            :eager="true"
            attach="#cmt-reply-selection-menu-container"
            :menu-props="{ attach: '#foo', value: articleReplyDialog, xeager: true, maxHeight: '200px' }"
            v-model="selectedReplyTemplate"
            :search-input.sync="replyTemplatesSearchInput"
            @change="replyTemplatesSearchInput = ''"
            ></v-autocomplete>
          <div id="cmt-reply-selection-menu-container" style="position: relative;">
          </div>
        </v-card-text>
      </v-card>
    </div>
  </v-container>
</template>

<script>
// Shorter version of querySelector
function sel(selector, context) {
  context ||= document;
  return context.querySelector(selector);
}

// Shorter version of querySelectorAll
function selAll(selector, context) {
  context ||= document;
  return context.querySelectorAll(selector);
}

function itemIcon(type) {
  return {
    AddNote:            'note-text',         // Note Added
    CustomerUpdate:     'account-outline',   // Customer Updated
    EmailAgent:         'email-send',        // Outgoing Email
    EmailCustomer:      'email-receive',     // Incoming Customer Email
    Lock:               'lock',              // Ticket Locked
    NewTicket:          'new-box',           // Ticket Created
    OwnerUpdate:        'account',           // New Owner
    PriorityUpdate:     'sort',              // Priority Updated
    Unlock:             'lock-open-variant', // Ticket Unlocked
    WebRequestCustomer: 'web',               // Incoming Web Request
  }[type] || 'cog';
}

module.exports = {
  props: {
    ticketId: Number,
  },
  data: function () {
    return {
      articleReplyDialog: false,
      
      timelineItems: [],
      timelineOrder: "descending",
      
      replyTemplates: [],

      replyTemplatesSearchInput: null,
      clickedReplyBtn: null,
      selectedReplyTemplate: null,
    };
  },
  watch: {
    clickedReplyBtn: function (btn) {
      var replySelectionDiv = sel('#cmt-reply-selection');
      sel('#app').appendChild(replySelectionDiv);

      var rect = btn.getBoundingClientRect();

      replySelectionDiv.style.left    = rect.right + window.scrollX + 'px';
      replySelectionDiv.style.top     = rect.top + window.scrollY + 'px';
      replySelectionDiv.style.display = 'initial';
    },
    selectedReplyTemplate: function () {
      this.triggerReply();
    },
    timelineOrder: function () {
      this.sortTimeline();
    }
  },
  methods: {
    triggerReply: function () {
      var articleId  = this.clickedReplyBtn.dataset.articleId;
      var origSelect = sel('#ResponseID' + articleId);
      
      origSelect.value = this.selectedReplyTemplate;
      origSelect.dispatchEvent(new Event('change'));

      this.$nextTick(function () {
        this.selectedReplyTemplate = null;
        this.replyTemplatesSearchInput = '';
        // TODO: Close reply selection as well
      });
    },
    sortTimeline: function () {
      var sortFunction;

      if (this.timelineOrder == 'ascending')
        sortFunction = function (itemA, itemB) {
          if (itemA.dateTimeString == itemB.dateTimeString)
            return itemA.itemOrder - itemB.itemOrder;
          else
            return itemA.dateTimeString > itemB.dateTimeString ? 1 : -1;
        };
      else
        sortFunction = function (itemA, itemB) {
          if (itemB.dateTimeString == itemA.dateTimeString)
            return itemB.itemOrder - itemA.itemOrder;
          else
            return itemB.dateTimeString > itemA.dateTimeString ? 1 : -1;
        };

       this.timelineItems.sort(sortFunction);
    }
  },
  created: function () {
    var userLanguage = window.Core.Config.Get('UserLanguage') || 'en';

    this.ticketId = window.__timeline.ticketId;

    this.timelineItems = [];

    dayjs.locale(userLanguage.replace('_', '-'));
    dayjs.extend(window.dayjs_plugin_relativeTime);

    var dateNow = dayjs();
    var itemOrder = 0;

    window.__timeline.historyItems.forEach(function (item) {
      var date = dayjs(item['CreateTime'], 'YYYY-MM-DD HH:mm:ss');
      var dateTimeRelative = date.from(dateNow);

      var timelineItem = {
        itemOrder:        itemOrder++,
        article:          null,
        type:             item['HistoryType'],
        title:            item['ItemTitle'],
        dateTimeString:   item['CreateTime'],
        dateTimeRelative: dateTimeRelative,
        icon:             itemIcon(item['HistoryType'])
      };

      var contentRegexp = new RegExp('^.*?<body.*?>|</body>.*?$', 'g');

      if (item['ArticleID']) {
        var article = {
          id:          item['ArticleID'],
          
          gravatarUrl: null,
          
          content:     '',
          
          replyTemplates: [],

          flags: {
            important: false,
            seen: false
          },

          flagAsImportantLink: null,
          printLink:           null,
        };

        var articleDiv = sel('div[data-cmt-article-id="' + article.id + '"]');

        var gravatarImg = sel('.ArticleSenderImage img', articleDiv);
        if (gravatarImg)
          article.gravatarUrl = gravatarImg.getAttribute('src');

        // Get article flags
        var articleRow =
          sel('#ArticleTable input.ArticleID[value="' + article.id + '"]')
            .parentElement  // td
            .parentElement; // tr

        article.flags.seen =
          sel('.UnreadArticles .fa-star', articleRow) != undefined;
        article.flags.important =
          sel('.UnreadArticles .fa-info-circle', articleRow) != undefined;

        // Get the anchor element to flag/unflag as important
        article.flagAsImportantLink =
          sel('a[href*=";Subaction=MarkAsImportant;"]', articleDiv);
        
        // Get the anchor element to print the article
        article.printLink =
          sel('a[href*="Action=AgentTicketPrint;"]', articleDiv);

        // Get the reply templates selectable for this article
        selAll('select[name="ResponseID"] option', articleDiv)
          .forEach(function (option, i) {
            if (!option.value)
              return true;

            this.replyTemplates.push({
              value: option.value,
              name:  option.textContent
            });
          }, article);

        var contentUrl = window.__timeline.baselink +
          'Action=AgentTicketArticleContent;' +
          'Subaction=HTMLView;' +
          'TicketID=' + this.ticketId + ';' +
          'ArticleID=' + item['ArticleID'];
        
        fetch(contentUrl)
          .then(function (response) {
            return response.text();
          })
          .then((function (text) {
            var content = '<div style="overflow: hidden;">' +
              text.replaceAll(contentRegexp, '') + '</div>';
            Vue.set(this, 'content', content);
          }).bind(article));

        timelineItem.article = article;
      }

      this.timelineItems.push(timelineItem);
    }, this);
  },
  mounted: function () {
    var actionsDiv = sel('#cmt-hide-original-ui > .WidgetSimple:first-child');
    
    sel('#cmt-ticket-timeline')
      .parentElement
      .insertBefore(actionsDiv, sel('#cmt-ticket-timeline'));

    // The reply template selection menu is not scrollable unless
    // the autocomplete input field has focus -- we work around that
    // by flagging the menu as active as soon as the mouse enters its container.
    sel('#cmt-reply-selection-menu-container').addEventListener('mouseenter',
      (function (event) {
        this.$refs['reply-selection-autocomplete'].isMenuActive = true;
      }).bind(this));
  }
}
</script>

<style scoped>
#cmt-ticket-timeline > .Content {
  background-color: rgb(245, 247, 250);
}

.v-timeline {
  padding-top: 0;
}

@media (min-width: 1264px) {
  .v-timeline {
    max-width: 75%;
  }
}

/* These styles create the shadow under the card pointer triangle
   and should be there by default, but Vuetify insists on adding the "link"
   class to the card (because there is a "@click" attribute), which overrides
   these styles -- so we need to add them explicitly. */
.v-timeline-item .v-card:before {
  background: initial;  
  border-bottom: 10px solid transparent;
  border-right: 10px solid #000;
  border-right-color: rgba(0, 0, 0, 0.12);
  border-top: 10px solid transparent;
  bottom: auto;
  left: -10px;
  opacity: 1;
  right: auto;
  top: 12px;
  transform: rotate(0);
}

.v-timeline-item .v-avatar {
  overflow: visible;
}

/* Item type icon displayed over sender avatar */
.v-timeline-item .v-avatar i.v-icon {
  background-color: #fff;
  bottom: -20%;
  box-shadow:
    0 2px 1px -1px rgb(0 0 0 / 20%),
    0 1px 1px 0 rgb(0 0 0 / 14%),
    0 1px 3px 0 rgb(0 0 0 / 12%);
  font-size: 18px;
  height: 55%;
  position: absolute;
  right: -20%;
  width: 55%;
}

.v-timeline-item .v-card__actions {
  align-items: start;
  justify-content: end;
}

.item-date {
  font-size: 0.875rem;
  line-height: 24px;
  margin-bottom: 4px;
  margin-top: -24px;
}

.cmt-reply-selection-container {
  position: relative;
}
</style>

<style>
.WidgetSimple .Header {
  /* TODO: Fix border-radius (this makes the header cover the rounded corners) */
  background-color: #f2f8fc;
}

#cmt-reply-selection {
  position: absolute;
  z-index: 1;
  margin-left: 12px;

  display: none;
}

#cmt-reply-selection .v-menu__content {
  box-shadow: none;
  max-width: initial;
  top: 0 !important;
  width: 100%;
}

#cmt-reply-selection .v-select__slot {
  width: 400px;
}

#cmt-reply-selection .v-select__slot input[type="text"] {
  border: none;
}

/* These styles add the card pointer triangle to the reply selection box */
#cmt-reply-selection .v-card:before {
  background: initial;
  border-bottom: 10px solid transparent;
  border-right: 10px solid rgba(0, 0, 0, 0.12);
  border-top: 10px solid transparent;
  content: "";
  inset: 12px auto auto -10px;
  left: -10px;
  opacity: 1;
  position: absolute;
  top: 12px;
  transform: rotate(0deg);
}

#cmt-reply-selection .v-card:after {
  border-right: 10px solid white;
  border-top: 10px solid transparent;
  border-bottom: 10px solid transparent;
  content: "";
  left: -10px;
  position: absolute;
  right: auto;
  top: 10px;
  transform: rotate(0);
}
</style>
