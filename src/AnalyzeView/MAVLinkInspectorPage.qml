/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import QtQuick.Window
import QtCharts

import QGroundControl
import QGroundControl.Palette
import QGroundControl.Controls
import QGroundControl.Controllers
import QGroundControl.ScreenTools

AnalyzePage {
    id: root
    headerComponent:    headerComponent
    pageComponent:      pageComponent
    allowPopout:        true

    property var    curSystem:          controller ? controller.activeSystem : null
    property var    curMessage:         curSystem && curSystem.messages.count ? curSystem.messages.get(curSystem.selected) : null
    property int    curCompID:          0
    property real   maxButtonWidth:     0

    property real battery_tension: 0
    property real gasoline_value: 0
    property real generator_curr: 0

    MAVLinkInspectorController {
        id: controller
    }

    Timer {
        interval: 10000; running: true; repeat: true
        onTriggered: { //IMPORTANTE: O INDICE DO CURSYSTEM.SELECTED MUDA. TEM QUE FAZER UMA FUNÇÃO PRA VASCULHAR.

            //console.log("Teste novo")
            //console.log(controller.activeSystem.messages.count)
            for (var i = 0; i < controller.activeSystem.messages.count; i++){

                //PEGAR VIOLAÇÕES DE ESPAÇO AEREO
                if (controller.activeSystem.messages.get(i).name === "FENCE_STATUS"){
                //    console.log("found");
                //    console.log(i)
                    curSystem.selected = i
                    var breach_count = controller.activeSystem.messages.get(5).fields.get(1).name
                    var breach_count_number = controller.activeSystem.messages.get(5).fields.get(1).value
                //    console.log(controller.activeSystem.messages.get(5).fields.get(1).value)


                    for (var j = 0; j < controller.activeSystem.messages.count; j++){
                        if (controller.activeSystem.messages.get(j).name === "GLOBAL_POSITION_INT"){
                            curSystem.selected = j
                    //        console.log(controller.activeSystem.messages.get(j).fields.get(1).name)
                    //        console.log(controller.activeSystem.messages.get(j).fields.get(2).name)
                            var current_lat = controller.activeSystem.messages.get(j).fields.get(1).value
                            var current_lon = controller.activeSystem.messages.get(j).fields.get(2).value
                            console.log("breach_count", breach_count_number, "pos: ",current_lat, current_lon," " ) //breach status
                        }
                    }
                }

                if (controller.activeSystem.messages.get(i).name ==="POWER_STATUS"){
                    curSystem.selected = i
                    //battery_tension = controller.activeSystem.messages.get(i).fields.get(0).value

                }

                if (controller.activeSystem.messages.get(i).name === "BATTERY_STATUS"){
                    curSystem.selected = i
                    var temp_id = controller.activeSystem.messages.get(i).fields.get(0).value
                    if (temp_id == 0){
                        battery_tension = controller.activeSystem.messages.get(i).fields.get(4).value.slice(0, 4);
                        //console.log("bat tension: ", battery_tension)
                    }
                    if (temp_id == 1){
                        gasoline_value = controller.activeSystem.messages.get(i).fields.get(4).value.slice(0, 4);
                        console.log("gasoline: ", gasoline_value)
                    }
                    if (temp_id == 2){
                        generator_curr = controller.activeSystem.messages.get(i).fields.get(5).value.slice(0, 4);
                        //console.log("generator curr: ", generator_curr)
                    }
                    console.log("ID: ", controller.activeSystem.messages.get(i).fields.get(0).value,controller.activeSystem.messages.get(i).fields.get(4).value)

                }

                   /* console.log(controller.activeSystem.messages.get(5).fields.get(1).type);
                    console.log(controller.activeSystem.messages.get(5).fields.get(1).value);
                    console.log(controller.activeSystem.messages.get(5).fields.get(1).rawValue);
                    console.log(controller.activeSystem.messages.get(5).fields.get(1).valueString);*/

            }

           /* curSystem.selected = 5
            var breach_count_number1 = controller.activeSystem.messages.get(5).fields.get(1).value
            console.log(controller.activeSystem.messages.get(5).fields.get(1).value)
            console.log("breach_count"," B ", breach_count_number1 ) //breach status
            console.log(controller.activeSystem.messages.get(5).fields.get(1).name) //breach status
            console.log(controller.activeSystem.messages.get(5).fields.get(1).type)
            console.log(controller.activeSystem.messages.get(5).fields.get(1).value)
            console.log(controller.activeSystem.messages.get(5).fields.get(1).rawValue)
            console.log(controller.activeSystem.messages.get(5).fields.get(1).valueString)
            console.log(controller.activeSystem.messages.get(5).fields.get(1).get(1))*/
            /*
            console.log(controller.activeSystem.messages.get(5).fields.get(1).name)
            console.log(controller.activeSystem.messages.get(5).fields.get(1).value)
            console.log(controller.activeSystem.messages.get(5).fields.get(1).type)
            curSystem.selected = 1
            console.log(controller.activeSystem.messages.get(1).fields.get(1).name)
            console.log(controller.activeSystem.messages.get(1).fields.get(1).value)
            console.log(controller.activeSystem.messages.get(1).fields.get(1).type)
            curSystem.selected = 2
            console.log(controller.activeSystem.messages.get(2).fields.get(1).name)
            console.log(controller.activeSystem.messages.get(2).fields.get(1).value)
            console.log(controller.activeSystem.messages.get(2).fields.get(1).type)
            curSystem.selected = 12 //heartbeat
            console.log("heartbeat " + controller.activeSystem.messages.get(10).count)
*/
            //_controller.currentGroupChanged()

            //console.log(tela_parametros._controller.ParameterEditorGroup.groups)
        }
    }

    Component {
        id:  headerComponent
        //-- Header
        RowLayout {
            id:                 header
            anchors.left:       parent.left
            anchors.right:      parent.right
            QGCLabel {
                text:           qsTr("Inspect real time MAVLink messages.")
            }
            RowLayout {
                Layout.alignment:   Qt.AlignRight
                visible:            curSystem ? controller.systemNames.length > 1 || curSystem.compIDsStr.length > 2 : false
                QGCComboBox {
                    id:             systemCombo
                    model:          controller.systemNames
                    sizeToContents: true
                    visible:        controller.systemNames.length > 1
                    onActivated: (index) =>  { controller.setActiveSystem(controller.systems.get(index).id) }

                    Connections {
                        target: controller
                        onActiveSystemChanged: {
                            for (var systemIndex=0; systemIndex<controller.systems.count; systemIndex++) {
                                if (controller.systems.get(systemIndex) == curSystem) {
                                    systemCombo.currentIndex = systemIndex
                                    curCompID = 0
                                    cidCombo.currentIndex = 0
                                    break
                                }
                            }
                        }
                    }
                }
                QGCComboBox {
                    id:             cidCombo
                    model:          curSystem ? curSystem.compIDsStr : []
                    sizeToContents: true
                    visible:        curSystem ? curSystem.compIDsStr.length > 2 : false
                    onActivated: (index) => {
                        if(curSystem && curSystem.compIDsStr.length > 1) {
                            if(index < 1)
                                curCompID = 0
                            else
                                curCompID = curSystem.compIDs[index - 1]
                        }
                    }
                }
            }
        }
    }

    Component {
        id:                         pageComponent
        Row {
            width:                  availableWidth
            height:                 availableHeight
            spacing:                ScreenTools.defaultFontPixelWidth
            //-- Messages (Buttons)
            QGCFlickable {
                id:                 buttonGrid
                flickableDirection: Flickable.VerticalFlick
                width:              maxButtonWidth
                height:             parent.height
                contentWidth:       width
                contentHeight:      buttonCol.height
                ColumnLayout {
                    id:             buttonCol
                    anchors.left:   parent.left
                    anchors.right:  parent.right
                    spacing:        ScreenTools.defaultFontPixelHeight * 0.25
                    Repeater {
                        model:      curSystem ? curSystem.messages : []
                        delegate:   MAVLinkMessageButton {
                            text:       object.name + (object.fieldSelected ?  " *" : "")
                            compID:     object.compId
                            checked:    curSystem ? (curSystem.selected === index) : false
                            messageHz:  object.actualRateHz
                            visible:    curCompID === 0 || curCompID === compID
                            onClicked: {
                                curSystem.selected = index
                            }
                            Layout.fillWidth: true
                        }
                    }
                }
            }
            //-- Message Data
            QGCFlickable {
                id:                 messageGrid
                visible:            curMessage !== null && (curCompID === 0 || curCompID === curMessage.compId)
                flickableDirection: Flickable.VerticalFlick
                width:              parent.width - buttonGrid.width - ScreenTools.defaultFontPixelWidth
                height:             parent.height
                contentWidth:       width
                contentHeight:      messageCol.height
                Column {
                    id:                 messageCol
                    width:              parent.width
                    spacing:            ScreenTools.defaultFontPixelHeight * 0.25
                    GridLayout {
                        columns:        2
                        columnSpacing:  ScreenTools.defaultFontPixelWidth
                        rowSpacing:     ScreenTools.defaultFontPixelHeight * 0.25
                        QGCLabel {
                            text: qsTr("Message:")
                            Layout.minimumWidth: ScreenTools.defaultFontPixelWidth * 20
                        }
                        QGCLabel {
                            color: qgcPal.buttonHighlight
                            text: curMessage ? curMessage.name + ' (' + curMessage.id + ')' : ""
                        }

                        QGCLabel { text: qsTr("Component:") }
                        QGCLabel { text: curMessage ? curMessage.compId : "" }

                        QGCLabel { text: qsTr("Count:") }
                        QGCLabel { text: curMessage ? curMessage.count : "" }

                        QGCLabel { text: qsTr("Actual Rate:") }
                        QGCLabel { text: curMessage ? curMessage.actualRateHz.toFixed(1) + qsTr("Hz") : "" }

                        QGCLabel { text: qsTr("Set Rate:") }
                        QGCComboBox {
                            id: msgRateCombo
                            textRole: "text"
                            valueRole: "value"
                            model: [
                                { value: -1, text: qsTr("Disabled") },
                                { value: 0, text: qsTr("Default") },
                                { value: 1, text: qsTr("1Hz") },
                                { value: 2, text: qsTr("2Hz") },
                                { value: 3, text: qsTr("3Hz") },
                                { value: 4, text: qsTr("4Hz") },
                                { value: 5, text: qsTr("5Hz") },
                                { value: 6, text: qsTr("6Hz") },
                                { value: 7, text: qsTr("7Hz") },
                                { value: 8, text: qsTr("8Hz") },
                                { value: 9, text: qsTr("9Hz") },
                                { value: 10, text: qsTr("10Hz") },
                                { value: 25, text: qsTr("25Hz") },
                                { value: 50, text: qsTr("50Hz") },
                                { value: 100, text: qsTr("100Hz") }
                            ]
                            Layout.alignment: Qt.AlignLeft
                            sizeToContents: true
                            Component.onCompleted: reset()
                            onActivated: (index) => controller.setMessageInterval(currentValue)
                            function reset() { currentIndex = indexOfValue(0) }
                            Connections {
                                target: root
                                function onCurMessageChanged() { msgRateCombo.reset() }
                            }
                            Connections {
                                target: curMessage
                                function onTargetRateHzChanged() {
                                    const target_index = indexOfValue(curMessage.targetRateHz)
                                    if(target_index != -1) {
                                        currentIndex = target_index
                                    }
                                }
                            }
                        }
                    }
                    Item { height: ScreenTools.defaultFontPixelHeight; width: 1 }
                    //---------------------------------------------------------
                    GridLayout {
                        id:                 msgInfoGrid
                        columns:            5
                        columnSpacing:      ScreenTools.defaultFontPixelWidth  * 0.25
                        rowSpacing:         ScreenTools.defaultFontPixelHeight * 0.25
                        width:              parent.width
                        QGCLabel {
                            text:       qsTr("Name")
                        }
                        QGCLabel {
                            text:       qsTr("Value")
                        }
                        QGCLabel {
                            text:       qsTr("Type")
                        }
                        QGCLabel {
                            text:       qsTr("Plot 1")
                        }
                        QGCLabel {
                            text:       qsTr("Plot 2")
                        }

                        //---------------------------------------------------------
                        Rectangle {
                            Layout.columnSpan:  5
                            Layout.fillWidth:   true
                            height:             1
                            color:              qgcPal.text
                        }
                        //---------------------------------------------------------

                        Repeater {
                            model:      curMessage ? curMessage.fields : []
                            delegate:   QGCLabel {
                                Layout.row:         index + 2
                                Layout.column:      0
                                Layout.minimumWidth: ScreenTools.defaultFontPixelWidth * 20
                                text:               object.name
                            }
                        }
                        Repeater {
                            model:      curMessage ? curMessage.fields : []
                            delegate:   QGCLabel {
                                Layout.row:         index + 2
                                Layout.column:      1
                                Layout.minimumWidth: msgInfoGrid.width * 0.25
                                Layout.maximumWidth: msgInfoGrid.width * 0.25
                                text:               object.value
                                elide:              Text.ElideRight
                            }
                        }
                        Repeater {
                            model:      curMessage ? curMessage.fields : []
                            delegate:   QGCLabel {
                                Layout.row:         index + 2
                                Layout.column:      2
                                Layout.minimumWidth: ScreenTools.defaultFontPixelWidth * 10
                                text:               object.type
                                elide:              Text.ElideRight
                            }
                        }
                        Repeater {
                            model:      curMessage ? curMessage.fields : []
                            delegate:   QGCCheckBox {
                                Layout.row:         index + 2
                                Layout.column:      3
                                Layout.alignment:   Qt.AlignHCenter
                                enabled: {
                                    if(checked)
                                        return true
                                    if(!object.selectable)
                                        return false
                                    if(object.series !== null)
                                        return false
                                    if(chart1.chartController !== null) {
                                        if(chart1.chartController.chartFields.length >= chart1.seriesColors.length)
                                            return false
                                    }
                                    return true;
                                }
                                checked:            object.series !== null && object.chartIndex === 0
                                onClicked: {
                                    if(checked) {
                                        chart1.addDimension(object)
                                    } else {
                                        chart1.delDimension(object)
                                    }
                                }
                            }
                        }
                        Repeater {
                            model:      curMessage ? curMessage.fields : []
                            delegate:   QGCCheckBox {
                                Layout.row:         index + 2
                                Layout.column:      4
                                Layout.alignment:   Qt.AlignHCenter
                                enabled: {
                                    if(checked)
                                        return true
                                    if(!object.selectable)
                                        return false
                                    if(object.series !== null)
                                        return false
                                    if(chart2.chartController !== null) {
                                        if(chart2.chartController.chartFields.length >= chart2.seriesColors.length)
                                            return false
                                    }
                                    return true;
                                }
                                checked:            object.series !== null && object.chartIndex === 1
                                onClicked: {
                                    if(checked) {
                                        chart2.addDimension(object)
                                    } else {
                                        chart2.delDimension(object)
                                    }
                                }
                            }
                        }
                    }
                    Item { height: ScreenTools.defaultFontPixelHeight * 0.25; width: 1 }
                    MAVLinkChart {
                        id:         chart1
                        height:     ScreenTools.defaultFontPixelHeight * 20
                        width:      parent.width
                    }
                    MAVLinkChart {
                        id:         chart2
                        height:     ScreenTools.defaultFontPixelHeight * 20
                        width:      parent.width
                    }
                }
            }
        }
    }
}
