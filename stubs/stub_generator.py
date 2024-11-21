import copy
import dearcygui as dcg
import inspect

level1 = "    "
level2 = level1 + level1
level3 = level2 + level1

def remove_jumps_start_and(s : str | None):
    if s is None:
        return None
    if len(s) < 2:
        return s
    if s[0] == '\n':
        s = s[1:]
    if s[-1] == '\n':
        s = s[:-1]
    return s

def indent(s: list[str] | str, trim_start=False):
    was_str = isinstance(s, str)
    if was_str:
        s = s.split("\n")
    s = [level1 + sub_s for sub_s in s]
    if trim_start:
        s0 = s[0].split(" ")
        s0 = [sub_s0 for sub_s0 in s0 if len(sub_s0) > 0]
        s[0] = " ".join(s0)
    if was_str:
        s = "\n".join(s)
    return s


hardcoded = {
    "parent": "baseItem | None",
    "font": "Font",
    "children": "list[baseItem]",
    "previous_sibling": "baseItem | None",
    "next_sibling": "baseItem | None",
    "color" : "int | tuple[int, int, int] | tuple[int, int, int, int] | tuple[float, float, float] | tuple[float, float, float, float]",
    "fill" : "int | tuple[int, int, int] | tuple[int, int, int, int] | tuple[float, float, float] | tuple[float, float, float, float]"
}

def typename(name, value):
    default = None if value is None else type(value).__name__
    return hardcoded.get(name, default)


def generate_docstring_for_class(object_class, instance):
    class_attributes = [v[0] for v in inspect.getmembers_static(object_class)]
    try:
        attributes = dir(instance)
    except:
        attributes = class_attributes
        pass
    dynamic_attributes = set(attributes).difference(set(class_attributes))
    disabled_properties = []
    read_only_properties = []
    writable_properties = []
    dynamic_properties = []
    methods = []
    properties = set()
    default_values = dict()
    docs = dict()
    for attr in sorted(attributes):
        if attr[:2] == "__":
            continue
        attr_inst = getattr(object_class, attr, None)
        if attr_inst is not None and inspect.isbuiltin(attr_inst):
            continue
        is_dynamic = attr in dynamic_attributes
        docs[attr] = remove_jumps_start_and(getattr(attr_inst, '__doc__', None))
        default_value = None
        is_accessible = False
        is_writable = False
        is_property = inspect.isdatadescriptor(attr_inst)
        is_class_method = inspect.ismethoddescriptor(attr_inst)
        try:
            if instance is None:
                raise ValueError
            default_value = getattr(instance, attr)
            is_accessible = True
            setattr(instance, attr, default_value)
            is_writable = True
        except AttributeError:
            pass
        except (TypeError, ValueError, OverflowError):
            is_writable = True
            pass
        if is_property:
            if is_writable:
                writable_properties.append(attr)
                properties.add(attr)
                default_values[attr] = default_value
            elif is_accessible:
                read_only_properties.append(attr)
                properties.add(attr)
                default_values[attr] = default_value
            else:
                disabled_properties.append(attr)
        elif is_dynamic and is_accessible:
            dynamic_properties.append(attr)
            properties.add(attr)
            default_values[attr] = default_value
        elif is_class_method:
            methods.append(attr_inst)

    result = []
    try:
        parent_class = object_class.__bases__[0]
        result += [
            f"class {object_class.__name__}({parent_class.__name__}):"
        ]
    except:
        result += [
            f"class {object_class.__name__}:"
        ]
    docstring = getattr(object_class, '__doc__', None)
    docstring = remove_jumps_start_and(docstring)
    if docstring is not None:
        result += [
            level1 + '"""',
            docstring,
            level1 + '"""'
        ]
    for method in [object_class.__init__] + methods:
        try:
            call_sig = inspect.signature(method)
        except:
            continue
        additional_properties = copy.deepcopy(properties)
        additional_properties = [p for p in additional_properties if p not in read_only_properties]
        call_str = level1 + "def " + method.__name__ + "("
        params_str = []
        kwargs_docs = []
        for (_, param) in call_sig.parameters.items():
            if method.__name__ not in ["__init__", "configure", "initialize"]:
                params_str.append(str(param))
                continue
            try:
                additional_properties.remove(param.name) 
            except:
                pass
            if param.name == 'args' and method.__name__ == "__init__":
                # Annotation seems incorrect for cython generated __init__
                params_str.append("context : Context")
                continue
            if param.name == 'kwargs':
                for prop in sorted(additional_properties):
                    if docs[prop] is not None:
                        doc = docs[prop]
                        if doc is not None:
                            doc = doc.split("attribute:")
                            if len(doc) == 1:
                                doc = doc[0]
                            elif len(doc) == 2:
                                doc = doc[1]
                            else:
                                assert(False)
                        doc = indent(doc, trim_start=True)
                        kwargs_docs.append(f"{level2}{prop}: {doc}")
                    v = default_values[prop]
                    v_type = typename(prop, v)
                    if v_type is None:
                        v_type = "Any"
                        v = "..."
                    elif v is not None and '<' in str(v): # default is a class
                        v = "..."
                    elif v_type == "NoneType": # Likely a class
                        v_type = "Any"
                        v = "..."
                    elif isinstance(v, str):
                        v = f'"{v}"'
                    if issubclass(object_class, dcg.SharedValue) and method.__name__ == "__init__":
                        params_str.append(f"{prop} : {v_type}")
                    else:
                        params_str.append(f"{prop} : {v_type} = {v}")
            else:
                params_str.append(str(param))
        call_str += ", ".join(params_str) + ')'
        if call_sig.return_annotation == inspect.Signature.empty:
            call_str += ':'
        else:
            call_str += f' -> {call_sig.return_annotation}:'
        result.append(call_str)
        docstring = remove_jumps_start_and(getattr(method, '__doc__', None))
        if len(kwargs_docs) > 0:
            kwargs_docs = "\n".join(kwargs_docs)
            if docstring is None:
                docstring = kwargs_docs
            else:
                docstring = "\n" + kwargs_docs
        if docstring is not None:
            result += [
                level2 + '"""',
                docstring,
                level2 + '"""'
            ]
        result.append(level2 + "...")
        result.append("\n")

    if hasattr(object_class, "__enter__"):
        result.append(f"{level1}def __enter__(self) -> {object_class.__name__}:")
        result.append(f"{level2}...")
        result.append("\n")

    for property in sorted(properties):
        result.append(level1 + "@property")
        definition = f"def {property}(self)"
        default_value = default_values.get(property, None)
        tname = typename(property, default_value)
        if tname is None:
            result.append(f"{level1}{definition}:")
        else:
            result.append(f"{level1}{definition} -> {tname}:")
        docstring = docs[property]
        if docstring is not None:
            if docstring[0] == " ":
                result += [
                    level2 + '"""',
                    docstring,
                    level2 + '"""'
                ]
            else:
                result += [
                    level2 + '"""' + docstring,
                    level2 + '"""'
                ]
        result.append(level2 + "...")
        result.append("\n")
        if property in read_only_properties:
            continue

        result.append(f"{level1}@{property}.setter")
        if tname is None:
            result.append(f"{level1}def {property}(self, value):")
        else:
            result.append(f"{level1}def {property}(self, value : {tname}):")
        result.append(level2 + "...")
        result.append("\n")

    return result







def get_pyi_for_classes(C):
    def is_item_sub_class(name, targets):
        try:
            item = getattr(dcg, name)
            for target in targets:
                if issubclass(item, target):
                    return True
        except Exception:
            return False
    filter_names = {
        "All": [dcg.baseItem, dcg.SharedValue],
        "Ui items": [dcg.uiItem, dcg.Texture, dcg.Font],
        "Handlers": [dcg.baseHandler],
        "Drawings": [dcg.drawingItem, dcg.Texture],
        "Plots": [dcg.plotElement, dcg.Plot, dcg.PlotAxisConfig, dcg.PlotLegendConfig],
        "Themes": [dcg.baseTheme],
        "Values": [dcg.SharedValue]
    }
    parent_classes = [dcg.Context, dcg.baseItem, dcg.SharedValue]
    dcg_items = dir(dcg)
    # remove items not starting with an upper case,
    # which are mainly for internal use, or items finishing by _
    #dcg_items = [i for i in dcg_items if i[0].isupper() and i[-1] != '_']
    #remove items that are not subclasses of the target.
    dcg_items = [i for i in dcg_items if is_item_sub_class(i, parent_classes)]
    result = []
    for name in dcg_items:
        object_class = getattr(dcg, name)
        if name == "Viewport":
            instance = C.viewport
        elif name == "Context":
            instance = C
        elif issubclass(object_class, dcg.SharedValue):
            instance = None
            for val in [0, (0, 0, 0, 0), 0., "", None]:
                try:
                    instance = object_class(C, val)
                    break
                except:
                    pass
        else:
            instance = object_class(C, attach=False)
        result += generate_docstring_for_class(object_class, instance)
    return "\n".join(result)

with open("../dearcygui/core.pyi", "w") as f:
    with open("custom.pyi", "r") as f2:
        f.write(f2.read())
    f.write(get_pyi_for_classes(dcg.Context()))
