"""
Module with various utils
"""
from typing import List, TYPE_CHECKING

from sql_metadata.keywords_lists import TABLE_ADJUSTMENT_KEYWORDS

if TYPE_CHECKING:  # pragma: no cover
    from sql_metadata.token import SQLToken


def unique(_list: List) -> List:
    """
    Makes the list have unique items only and maintains the order

    list(set()) won't provide that

    :type _list list
    :rtype: list
    """
    ret = []

    for item in _list:
        if item not in ret:
            ret.append(item)

    return ret


def update_table_names(tables: List[str], token: "SQLToken", index: int) -> List[str]:
    """
    Return new table names matching database.table or database.schema.table notation

    :type tables list[str]
    :type token sql_metadata.token.SQLToken
    :type index int
    :rtype: list[str]
    """
    if (
        token.last_keyword_normalized in TABLE_ADJUSTMENT_KEYWORDS
        and token.previous_token.upper not in ["AS", "WITH"]
        and token.upper not in ["AS", "SELECT"]
    ):
        schema_notation_tokens = (
            (
                token.get_nth_previous(4).is_name,
                token.get_nth_previous(3).is_dot,
                token.get_nth_previous(2).is_name,
                token.previous_token.is_dot,
                token.is_name,
            )
            if index > 4
            else [False]
        )
        if all(schema_notation_tokens):
            # we have database.schema.table notation example
            table_name = "{}.{}.{}".format(
                token.get_nth_previous(4), token.get_nth_previous(2), token
            )
            tables.append(table_name)
        elif token.previous_token.is_dot and not token.next_token.is_dot:
            # we have database.table notation example
            table_name = "{}.{}".format(token.get_nth_previous(2), token)
            tables.append(table_name)
        elif (
            (
                token.previous_token.normalized != token.last_keyword_normalized
                and not token.previous_token.is_punctuation
            )
            or token.next_token.is_dot
            or (token.last_keyword_normalized == "INTO" and token.is_in_parenthesis)
            or token.previous_token.is_right_parenthesis
        ):
            # and token.last_keyword_normalized not in ["INTO", "FROM"]

            # it's not a list of tables, e.g. SELECT * FROM foo, bar
            # hence, it can be the case of alias without AS, e.g. SELECT * FROM foo bar
            pass
        else:
            table_name = str(token.value.strip("`"))
            tables.append(table_name)

    return tables
