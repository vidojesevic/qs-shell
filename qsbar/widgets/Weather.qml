import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

import "../../config.js" as Config

Text {
    id: weatherRoot

    property string city: "Belgrade"

    property string location: ""
    property string condition: ""
    property int temp: 0
    property int feelsLike: 0
    property int humidity: 0
    property int windSpeed: 0
    property string windDir: ""
    property int pressure: 0
    property real precip: 0
    property int uvIndex: 0
    property int cloudCover: 0
    property int visibility: 0
    property string observed: ""

    property string sunrise: ""
    property string sunset: ""
    property string moonPhase: ""
    property int moonIllumination: 0

    // False until the first successful fetch, or after a failed one.
    property bool loaded: false

    text: weatherIcon(condition) + " "
        + (loaded ? (temp > 0 ? "+" : "") + temp + "°C" : "N/A")

    color: weatherPopup.visible ? Config.text.active : Config.text.normal

    leftPadding: Config.bar.padding
    rightPadding: Config.bar.padding

    font {
        family: Config.bar.fontFamily
        pixelSize: Config.bar.fontSize
        bold: true
    }

    // Nerd Font glyph for a wttr.in condition name, so the icon takes a
    // text color. The emoji wttr returns for %c would ignore one.
    function weatherIcon(condition) {
        const c = condition.toLowerCase()

        if (c.includes("thunder"))
            return "󰖓"

        if (c.includes("fog") || c.includes("mist") || c.includes("haze"))
            return "󰖑"

        if (c.includes("snow") || c.includes("blizzard"))
            return "󰖘"

        if (c.includes("sleet") || c.includes("ice pellets")
            || c.includes("hail") || c.includes("freezing"))
            return "󰖒"

        if (c.includes("torrential") || c.includes("heavy rain"))
            return "󰖖"

        if (c.includes("rain") || c.includes("drizzle") || c.includes("shower"))
            return "󰖗"

        if (c.includes("partly"))
            return "󰖕"

        if (c.includes("overcast") || c.includes("cloud"))
            return "󰖐"

        if (c.includes("sunny"))
            return "󰖙"

        if (c.includes("clear"))
            return "󰖔"

        if (c.includes("wind") || c.includes("blowing"))
            return "󰖝"

        return "󰖐"
    }

    // "2026-09-18" to "Today", "Tomorrow" or a weekday name.
    function dayName(date, index) {
        if (index === 0)
            return "Today"

        if (index === 1)
            return "Tomorrow"

        return Qt.formatDate(Date.fromLocaleDateString(
            Qt.locale(), date, "yyyy-MM-dd"), "dddd")
    }

    // "06:20 AM" to "06:20", the rest of the bar is 24 hour.
    function hour24(time) {
        const parts = time.match(/(\d+):(\d+) (AM|PM)/)

        if (!parts)
            return time

        let hours = parseInt(parts[1]) % 12

        if (parts[3] === "PM")
            hours += 12

        return (hours < 10 ? "0" : "") + hours + ":" + parts[2]
    }

    // [{ day, icon, min, max, rain }], one entry per forecast day.
    ListModel {
        id: forecast
    }

    Process {
        id: weatherProc

        command: [
            "curl",
            "-fsSL",
            "--max-time",
            "10",
            "https://wttr.in/" + weatherRoot.city + "?format=j1"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim() === "") {
                    weatherRoot.loaded = false
                    return
                }

                const data = JSON.parse(text)
                const now = data.current_condition[0]
                const area = data.nearest_area[0]

                weatherRoot.location = area.areaName[0].value
                    + ", " + area.country[0].value

                weatherRoot.condition = now.weatherDesc[0].value.trim()
                weatherRoot.temp = parseInt(now.temp_C)
                weatherRoot.feelsLike = parseInt(now.FeelsLikeC)
                weatherRoot.humidity = parseInt(now.humidity)
                weatherRoot.windSpeed = parseInt(now.windspeedKmph)
                weatherRoot.windDir = now.winddir16Point
                weatherRoot.pressure = parseInt(now.pressure)
                weatherRoot.precip = parseFloat(now.precipMM)
                weatherRoot.uvIndex = parseInt(now.uvIndex)
                weatherRoot.cloudCover = parseInt(now.cloudcover)
                weatherRoot.visibility = parseInt(now.visibility)
                weatherRoot.observed = weatherRoot.hour24(now.observation_time)

                const astronomy = data.weather[0].astronomy[0]

                weatherRoot.sunrise = weatherRoot.hour24(astronomy.sunrise)
                weatherRoot.sunset = weatherRoot.hour24(astronomy.sunset)
                weatherRoot.moonPhase = astronomy.moon_phase
                weatherRoot.moonIllumination =
                    parseInt(astronomy.moon_illumination)

                forecast.clear()

                for (let i = 0; i < data.weather.length; i++) {
                    const day = data.weather[i]

                    let rain = 0

                    for (let h = 0; h < day.hourly.length; h++)
                        rain = Math.max(rain, parseInt(day.hourly[h].chanceofrain))

                    // The midday slot stands in for the whole day.
                    const midday = day.hourly[4]

                    forecast.append({
                        day: weatherRoot.dayName(day.date, i),
                        icon: weatherRoot.weatherIcon(midday.weatherDesc[0].value),
                        min: parseInt(day.mintempC),
                        max: parseInt(day.maxtempC),
                        rain: rain
                    })
                }

                weatherRoot.loaded = true
            }
        }
    }

    Timer {
        interval: 600000
        running: true
        repeat: true

        onTriggered: weatherProc.running = true
        Component.onCompleted: weatherProc.running = true
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor

        onClicked: weatherPopup.visible = !weatherPopup.visible
    }

    // Close if inactive
    Timer {
        id: popupCloseTimer

        interval: 5000
        repeat: false

        onTriggered: {
            weatherPopup.visible = false
        }
    }

    PopupWindow {
        id: weatherPopup

        anchor {
            item: weatherRoot

            edges: Edges.Bottom | Edges.Right
            gravity: Edges.Bottom | Edges.Left

            margins.top: 32
            margins.right: 16
        }

        implicitWidth: 420
        implicitHeight: content.implicitHeight + 28

        visible: false
        color: "transparent"
        grabFocus: true

        onVisibleChanged: {
            if (visible)
                popupCloseTimer.restart()
            else
                popupCloseTimer.stop()
        }

        Rectangle {
            anchors.fill: parent

            radius: 8
            color: Config.colors.background

            border {
                width: 1
                color: Config.colors.muted
            }

            // Keep popup open while pointer is over it.
            HoverHandler {
                onHoveredChanged: {
                    if (hovered)
                        popupCloseTimer.stop()
                    else
                        popupCloseTimer.restart()
                }
            }

            ColumnLayout {
                id: content

                anchors.fill: parent
                anchors.margins: 14
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: "Weather"
                        color: Config.text.active

                        font {
                            family: Config.bar.fontFamily
                            pixelSize: Config.bar.fontSize + 2
                            bold: true
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    Text {
                        text: weatherRoot.location
                        color: Config.text.dim
                        elide: Text.ElideRight

                        font {
                            family: Config.bar.fontFamily
                            pixelSize: Config.bar.fontSize - 3
                        }
                    }

                    Text {
                        text: "󰑐"
                        color: Config.text.dim

                        font {
                            family: Config.bar.fontFamily
                            pixelSize: Config.bar.fontSize - 2
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor

                            onClicked: weatherProc.running = true
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Text {
                        text: weatherRoot.weatherIcon(weatherRoot.condition)
                        color: Config.text.normal

                        font {
                            family: Config.bar.fontFamily
                            pixelSize: Config.bar.fontSize + 16
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        Text {
                            text: (weatherRoot.temp > 0 ? "+" : "")
                                + weatherRoot.temp + "°C"

                            color: Config.text.normal

                            font {
                                family: Config.bar.fontFamily
                                pixelSize: Config.bar.fontSize + 8
                                bold: true
                            }
                        }

                        Text {
                            text: weatherRoot.condition
                            color: Config.text.dim
                            elide: Text.ElideRight

                            Layout.fillWidth: true

                            font {
                                family: Config.bar.fontFamily
                                pixelSize: Config.bar.fontSize - 3
                            }
                        }
                    }

                    ColumnLayout {
                        spacing: 0

                        Text {
                            Layout.alignment: Qt.AlignRight

                            text: "feels " + (weatherRoot.feelsLike > 0 ? "+" : "")
                                + weatherRoot.feelsLike + "°C"

                            color: Config.text.normal

                            font {
                                family: Config.bar.fontFamily
                                pixelSize: Config.bar.fontSize
                                bold: true
                            }
                        }

                        Text {
                            Layout.alignment: Qt.AlignRight

                            text: weatherRoot.observed === ""
                                ? "" : "at " + weatherRoot.observed

                            color: Config.text.dim

                            font {
                                family: Config.bar.fontFamily
                                pixelSize: Config.bar.fontSize - 3
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: Config.colors.muted
                }

                GridLayout {
                    Layout.fillWidth: true

                    columns: 2
                    columnSpacing: 16
                    rowSpacing: 4

                    Repeater {
                        model: [
                            {
                                label: "Wind",
                                value: weatherRoot.windSpeed + " km/h "
                                    + weatherRoot.windDir
                            },
                            { label: "Humidity", value: weatherRoot.humidity + "%" },
                            { label: "Pressure", value: weatherRoot.pressure + " hPa" },
                            { label: "Precipitation", value: weatherRoot.precip + " mm" },
                            { label: "Cloud cover", value: weatherRoot.cloudCover + "%" },
                            { label: "UV index", value: weatherRoot.uvIndex },
                            { label: "Visibility", value: weatherRoot.visibility + " km" },
                            {
                                label: "Moon",
                                value: weatherRoot.moonPhase + " "
                                    + weatherRoot.moonIllumination + "%"
                            }
                        ]

                        delegate: RowLayout {
                            required property var modelData

                            Layout.fillWidth: true
                            spacing: 6

                            Text {
                                text: modelData.label
                                color: Config.text.dim

                                font {
                                    family: Config.bar.fontFamily
                                    pixelSize: Config.bar.fontSize - 3
                                }
                            }

                            Item {
                                Layout.fillWidth: true
                            }

                            Text {
                                text: modelData.value
                                color: Config.text.normal
                                elide: Text.ElideRight

                                font {
                                    family: Config.bar.fontFamily
                                    pixelSize: Config.bar.fontSize - 3
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: Config.colors.muted
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 16

                    Text {
                        text: "󰖜 " + weatherRoot.sunrise
                        color: Config.text.normal

                        font {
                            family: Config.bar.fontFamily
                            pixelSize: Config.bar.fontSize - 3
                            bold: true
                        }
                    }

                    Text {
                        text: "󰖛 " + weatherRoot.sunset
                        color: Config.text.normal

                        font {
                            family: Config.bar.fontFamily
                            pixelSize: Config.bar.fontSize - 3
                            bold: true
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: Config.colors.muted
                }

                Text {
                    text: "Forecast"
                    color: Config.text.dim

                    font {
                        family: Config.bar.fontFamily
                        pixelSize: Config.bar.fontSize - 3
                    }
                }

                Repeater {
                    model: forecast

                    delegate: RowLayout {
                        required property string day
                        required property string icon
                        required property int min
                        required property int max
                        required property int rain

                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            Layout.fillWidth: true

                            text: day
                            color: Config.text.normal
                            elide: Text.ElideRight

                            font {
                                family: Config.bar.fontFamily
                                pixelSize: Config.bar.fontSize - 3
                            }
                        }

                        Text {
                            text: icon
                            color: Config.text.normal

                            font {
                                family: Config.bar.fontFamily
                                pixelSize: Config.bar.fontSize - 3
                            }
                        }

                        Text {
                            text: "󰖗 " + rain + "%"

                            color: rain >= 50
                                ? Config.text.active
                                : Config.text.dim

                            font {
                                family: Config.bar.fontFamily
                                pixelSize: Config.bar.fontSize - 3
                            }
                        }

                        Text {
                            text: min + "° / " + max + "°"
                            color: Config.text.normal

                            font {
                                family: Config.bar.fontFamily
                                pixelSize: Config.bar.fontSize - 3
                                bold: true
                            }
                        }
                    }
                }
            }
        }
    }
}
