pragma Singleton

import QtQuick
import Quickshell

/**
 * WeatherService: Passive stub to conserve system resources and eliminate background polling.
 */
Singleton {
    id: root

    property string temp: ""
    property string tempFull: ""
    property real tempVal: 0.0
    property string feelsLike: ""
    property string condition: ""
    property string icon: ""
    property string wind: ""
    property string humidity: ""
    property string city: ""
    property string provider: ""
    property string statusMessage: ""
    property bool isError: false
    property bool isFetching: false
    property var forecast: []
    property var hourly: []

    property string configApiUrl: ""
    property string configApiKey: ""
    property string configCity: ""
    readonly property bool hasKey: false

    function fetchWeather() {}
    function searchLocation(newCity) {}
    function useDeviceLocation() {}
    function saveAndFetch(newUrl, newKey, newCity) {}
}
