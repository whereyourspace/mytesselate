from __future__ import (absolute_import, division, print_function)


__metaclass__ = type


from ansible.module_utils.common.text.converters import (
    to_text,
)


def extract(map, keys):
    return { key : value for key, value in map.items() if key in keys }


def format(map, str):
    return to_text(str.format(**map))


def to_dict(obj, key, attrs={}):
    return { key: obj } | attrs


def __dict_list_iterator(obj):
    if isinstance(obj, dict):
        for key, value in obj.items():
            yield key, value
    elif isinstance(obj, list):
        for ind, value in enumerate(obj):
            yield ind, value
    else:
        raise TypeError(f'expected dict or list. received: {obj.__class__.__name__}')


def flatten_dict(map, parent_keys=[ ], key_name="key", value_name="value", ind=0):
    attrs = [ ]

    for key, value in __dict_list_iterator(map):
        if isinstance(value, dict) or isinstance(value, list):
            has_key_names = len(parent_keys) >= 1
            parent_name = parent_keys[0] if has_key_names else f'key_{ind}'
            inner_attrs = flatten_dict(value, parent_keys[1:] if has_key_names else [ ], key_name, value_name, ind+1)
            for attr in inner_attrs:
                attr[parent_name] = key
            attrs.extend(inner_attrs)
        else:
            attrs.append({key_name: key, value_name: value})
    
    return attrs


class FilterModule:
    def filters(self):
        return {
            'extract': extract,
            'format': format,
            'to_dict': to_dict,
            'flatten_dict': flatten_dict,
        }
