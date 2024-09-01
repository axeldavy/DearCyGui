## DearPyGui

DearPyGui (https://github.com/hoffstadt/DearPyGui) is a project for enabling easy use of Dear ImGui (https://github.com/ocornut/imgui) in Python.

## The goal of DearCyGui

DearPyGui is written in C++. This enables an efficient wrapping of Dear ImGui calls.

Dear ImGui is an immediate API. Basically every frame everything is redrawn.
Since Python is significantly slower than C++, the basic idea is that instead of rendering every frame with Python calling Dear ImGui, the Python application instead creates objects that are managed by C++ code. These C++ objects are used to render every frame the objects with Dear ImGui. Thus the main overhead of using Python for the GUI is the application logic + the logic of creating the objects that the C++ will manage.

Why DearCyGui ? Basically DearPyGui has to make many CPython calls in order to retrieve the arguments passed from Python. This has several downsides:
- This complicates the logic. CPython requires specific handling for various types of arguments, in addition to the Global Interpreter Lock and the Python object refcount.
- Since the logic is complicated, the code remains simple in order to be easy to maintain and thus some optimizations are left out.
For example if one calls ```dpg.configure_item(tag, show=True)```, the C++ library has to find if tag corresponds to any object, then the object uses CPython calls for each possible parameter if configure_item passed it, and if so apply the new parameter. Each CPython call is quite costly.
- In addition some nice features are not implemented. For example instead of creating Python objects, each C++ object corresponds to a UUID and an optional user string tag. As a result the user has to pass the UUID/tag to each call. An alternative more pythonic-way would be to use Python objects instead of UUID/tags. In fact Python enables libraries to provide objects with C++ defined behaviour for various aspects. For example ```dpg.configure_item(tag, show=True)``` could be replaced by ```my_python_object.show = True```. Python enables the C++ library to define what behaviour should happen when specifically show is set.

Basically Cython is a way to fix all the above issues. Cython code looks python-like but it is converted to C/C++ code. It can thus interact to both C++ and Python directly. The required CPython calls are made directly and in an optimized way. This simplifies the logic and enables to implement new behaviours. In addition the Cython provided functions can be accessed either from Python or directly using Cython code. Using Cython code to use the library will enable a performance boost as many CPython calls can be removed. Cython generates code for both paths.

## How can the old API and the new features co-exist

DearCyGui strives for retrocompatibility with the old API. One way to achieve this would be to leave the C++ code mostly untouched, and add Cython interfaces to interact directly with the C++ objects. This means that there will be no performance boost unless the Cython paths are used.

Instead of going this way, this repository tries to go for a harder path: reimplementing part of the logic in Cython. In particular use Cython to handle the CPython calls and remove the direct calls to CPython in the C++ code. And doing so, add all the new features and the performance optimizations that are easy to add thanks to Cython. The compatibility with the old API is maintained by appropriate calls to the Cython objects, but the objects being accessible from Python, newer applications can manipulate them directly.

This means performance gains can be obtained even using only Python on the application side:
- There will be a small performance boost since Cython generates more optimized code to access the input arguments
- Using the objects instead of the tags in application code will give a more significant boost. For example ```my_python_object.show = True``` will directly call a function that sets the value of ```show```. Unlike with ```dpg.configure_item(tag, show=True)``` which has to check the kwargs dictionnary passed to find which fields need to be updated. Fewer CPython calls are generated.
- The simplicity brought by using Cython means multithreading can be handled more simply on DearCyGui side. We should be able to manipulate several objects from several Python threads without a global DearPyGui lock.