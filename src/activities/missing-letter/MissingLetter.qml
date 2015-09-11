/* GCompris - missing-letter.qml
 *
 * Copyright (C) 2014 "Amit Tomar" <a.tomar@outlook.com>
 *
 * Authors:
 *   "Pascal Georges" <pascal.georgis1.free.fr> (GTK+ version)
 *   "Amit Tomar" <a.tomar@outlook.com> (Qt Quick port)
 *
 *   This program is free software; you can redistribute it and/or modify
 *   it under the terms of the GNU General Public License as published by
 *   the Free Software Foundation; either version 3 of the License, or
 *   (at your option) any later version.
 *
 *   This program is distributed in the hope that it will be useful,
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *   GNU General Public License for more details.
 *
 *   You should have received a copy of the GNU General Public License
 *   along with this program; if not, see <http://www.gnu.org/licenses/>.
 */
import QtQuick 2.1
import GCompris 1.0

import "../../core"
import "missing-letter.js" as Activity

ActivityBase
{
    id: activity

    onStart: focus = true
    onStop: {}

    // When going on configuration, it steals the focus and re set it to the activity.
    // We need to set it back to the textinput item in order to have key events.
    onFocusChanged: {
        if(focus) {
            Activity.focusTextInput()
        }
    }
    pageComponent: Image
    {
        id: background
        source: Activity.url + "background.svg"
        sourceSize.width: parent.width
        fillMode: Image.PreserveAspectCrop
        readonly property string wordsResource: "data2/words/words.rcc"
        property bool englishFallback: false
        property bool downloadWordsNeeded: false

        signal start
        signal stop

        Component.onCompleted:
        {
            activity.start.connect(start)
            activity.stop.connect(stop)
        }

        // Add here the QML items you need to access in javascript
        QtObject
        {
            id: items
            property Item  main: activity.main
            property alias background: background
            property alias bar: bar
            property alias bonus: bonus
            property alias score: score
            property alias questionImage: questionImage
            property alias questionText: questionText
            property alias answers: answers
            property GCAudio audioVoices: activity.audioVoices
            property alias englishFallbackDialog: englishFallbackDialog
            property alias parser: parser
            property string answer
            property alias textinput: textinput
        }

        function handleResourceRegistered(resource)
        {
            if (resource == wordsResource)
                Activity.start();
        }

        onStart: {
            Activity.init(items)
            Activity.focusTextInput()

            // check for words.rcc:
            if (DownloadManager.isDataRegistered("words")) {
                // words.rcc is already registered -> start right away
                Activity.start();
            } else if(DownloadManager.haveLocalResource(wordsResource)) {
                // words.rcc is there -> register old file first
                if (DownloadManager.registerResource(wordsResource))
                    Activity.start(items);
                else // could not register the old data -> react to a possible update
                    DownloadManager.resourceRegistered.connect(handleResourceRegistered);
                // then try to update in the background
                DownloadManager.updateResource(wordsResource);
            } else {
                // words.rcc has not been downloaded yet -> ask for download
                downloadWordsNeeded = true
            }
        }
        onStop: {
            DownloadManager.resourceRegistered.disconnect(handleResourceRegistered);
            Activity.stop()
        }

        TextInput {
            // Helper element to capture composed key events like french ô which
            // are not available via Keys.onPressed() on linux. Must be
            // disabled on mobile!
            id: textinput
            anchors.centerIn: background
            enabled: !ApplicationInfo.isMobile
            focus: true
            visible: false

            // TODO, do we want to have keyboard input disreguards casing
            property bool uppercaseOnly: false

            onTextChanged: {
                if (text != '') {
                    var typedText = uppercaseOnly ? text.toLocaleUpperCase() : text;
                    var question = Activity.getCurrentQuestion()
                    if(typedText === question.answer) {
                        questionAnim.start()
                        Activity.showAnswer()
                    }
                    text = '';
                }
            }
        }

        // Buttons with possible answers shown on the left of screen
        Column
        {
            id: buttonHolder
            spacing: 10 * ApplicationInfo.ratio
            x: holder.x - width - 10 * ApplicationInfo.ratio
            y: holder.y

            add: Transition {
                NumberAnimation { properties: "y"; from: holder.y; duration: 500 }
            }

            Repeater
            {
                id: answers

                AnswerButton {
                    width: 120 * ApplicationInfo.ratio
                    height: (holder.height
                             - buttonHolder.spacing * answers.model.length) / answers.model.length
                    textLabel: modelData
                    isCorrectAnswer: modelData === items.answer
                    onCorrectlyPressed: questionAnim.start()
                    onPressed: modelData == items.answer ? Activity.showAnswer() : ''
                }
            }
        }

        // Picture holder for different images being shown
        Rectangle
        {
            id: holder
            width: Math.max(questionImage.width * 1.1, questionImage.height * 1.1)
            height: questionTextBg.y + questionTextBg.height
            x: (background.width - width - 130 * ApplicationInfo.ratio) / 2 +
               130 * ApplicationInfo.ratio
            y: 20
            color: "black"
            radius: 10
            border.width: 2
            border.color: "black"
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#80FFFFFF" }
                GradientStop { position: 0.9; color: "#80EEEEEE" }
                GradientStop { position: 1.0; color: "#80AAAAAA" }
            }

            Item
            {
                id: spacer
                height: 20
            }

            Image
            {
                id: questionImage
                anchors.horizontalCenter: holder.horizontalCenter
                anchors.top: spacer.bottom
                width: Math.min((background.width - 120 * ApplicationInfo.ratio) * 0.7,
                                (background.height - 100 * ApplicationInfo.ratio) * 0.7)
                height: width
            }

            Rectangle {
                id: questionTextBg
                width: holder.width
                height: questionText.height * 1.1
                anchors.horizontalCenter: holder.horizontalCenter
                anchors.top: questionImage.bottom
                radius: 10
                border.width: 2
                border.color: "black"
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#000" }
                    GradientStop { position: 0.9; color: "#666" }
                    GradientStop { position: 1.0; color: "#AAA" }
                }

                GCText {
                    id: questionText
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    style: Text.Outline
                    styleColor: "black"
                    color: "white"
                    fontSize: largeSize
                    wrapMode: Text.WordWrap
                    width: holder.width

                    SequentialAnimation {
                        id: questionAnim
                        NumberAnimation {
                            target: questionText
                            property: 'scale'
                            to: 1.05
                            duration: 500
                            easing.type: Easing.OutQuad
                        }
                        NumberAnimation {
                            target: questionText
                            property: 'scale'
                            to: 0.95
                            duration: 1000
                            easing.type: Easing.OutQuad
                        }
                        NumberAnimation {
                            target: questionText
                            property: 'scale'
                            to: 1.0
                            duration: 500
                            easing.type: Easing.OutQuad
                        }
                        ScriptAction {
                            script: Activity.nextSubLevel()
                        }
                    }
                }
            }


        }

        Score {
            id: score
            anchors.bottom: undefined
            anchors.bottomMargin: 10 * ApplicationInfo.ratio
            anchors.right: parent.right
            anchors.rightMargin: 10 * ApplicationInfo.ratio
            anchors.top: parent.top
        }

        DialogHelp
        {
            id: dialogHelp
            onClose: home()
        }

        Bar
        {
            id: bar
            content: BarEnumContent { value: help | home | level | repeat }
            onHelpClicked: displayDialog(dialogHelp)
            onPreviousLevelClicked: Activity.previousLevel()
            onNextLevelClicked: Activity.nextLevel()
            onHomeClicked: activity.home()
            onRepeatClicked: Activity.playCurrentWord()
        }

        Bonus
        {
            id: bonus
            Component.onCompleted: win.connect(Activity.nextLevel)
        }

        JsonParser {
            id: parser
            onError: console.error("missing letter: Error parsing json: " + msg);
        }

        Loader {
            id: downloadWordsDialog
            sourceComponent: GCDialog {
                parent: activity.main
                message: qsTr("The images for this activity are not yet installed.")
                button1Text: qsTr("Download the images")
                onClose: background.downloadWordsNeeded = false
                onButton1Hit: {
                    DownloadManager.resourceRegistered.connect(handleResourceRegistered);
                    DownloadManager.downloadResource(wordsResource)
                    var downloadDialog = Core.showDownloadDialog(activity, {});
                }
            }
            anchors.fill: parent
            focus: true
            active: background.downloadWordsNeeded
            onStatusChanged: if (status == Loader.Ready) item.start()
        }

        Loader {
            id: englishFallbackDialog
            sourceComponent: GCDialog {
                parent: activity.main
                message: qsTr("We are sorry, we don't have yet a translation for your language.") + " " +
                         qsTr("GCompris is developed by the KDE community, you can translate GCompris by joining a translation team on <a href=\"%2\">%2</a>").arg("http://l10n.kde.org/") +
                         "<br /> <br />" +
                         qsTr("We switched to English for this activity but you can select another language in the configuration dialog.")
                onClose: background.englishFallback = false
            }
            anchors.fill: parent
            focus: true
            active: background.englishFallback
            onStatusChanged: if (status == Loader.Ready) item.start()
        }

    }
}
