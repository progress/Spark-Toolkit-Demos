# Progress Spark Toolkit Client Library

Client-side helper library for Telerik KendoUI + Progress JSDO applications.


## Requirements

Apache Ant 1.9.x+ (Building)

jQuery 1.12.x (Runtime)

KendoUI 2017.1+ (Runtime)

Progress JSDO 4.3+ (Runtime)

Bootstrap 3.3.x (Optional)

FontAwesome 4.3.x (Optional)


## Assumptions

Presence of a **/vendor/** folder within the **PASOEContent/static/** directory of your project. This is a highly-suggested, common location for third-party libraries that will be used for your front-end application. It is further assumed that use of this library will be in conjunction with KendoUI as your UI library of choice. If you are **not** utilizing KendoUI then STOP as you do not need this library.


## Installation / Setup

This repository should be downloaded and included within a directory **/vendor/spark/** alongside any other third-party bundles such as KendoUI and jQuery. To use the library simply include **/vendor/spark/lib/spark.min.js** (per the recommended directory structure) within your application's HTML document(s). If using an Single-Page Application (SPA) pattern you only need to include this in your parent index/login/app HTML document(s).

Once included in your application, the library will be available as a global JavaScript object "spark" and accessible via your browser's development console (eg. Chrome DevTools, Firebug for Firefox, etc.) for interrogation of available methods and properties.

Additionally, there is a **/lib/plugins.js** file that provides for extended features in the Progress JSDO, such as the ABL Filter Pattern (AFP) as a Mapping Type in your Business Entitites. As an example, this would give you the ability to pass a Kendo criteria object as-is from grids and datasources, rather than the standard JFP behavior of a pre-formed "where" clause.


## Contributions / Changes

This library should be ready to use as-is. However, if modifications are needed they can be made within the **/src/** directory. To prepare for usage in your web application run `ant compile` from within the **/src/** directory to create a new minified version of the **/lib/spark.min.js** file.


## Generating Documentation

To utilize JSDoc to create documentation from the resulting output, be sure that you first have **JSDoc3** installed. This can be done easily via **Node.js** with the command `npm install jsdoc`. The proper task for Ant will already be present in the build script found in **/src/**, and available to execute by running `ant document` from that directory. To utilize the JSDoc binary properly within Ant, you must adjust the Ant property called **"jsdoc.home"** to point to your global NPM modules directory. This is typically located at **"C:\Users\\[username]\AppData\Roaming\npm"** on Windows7 and later.