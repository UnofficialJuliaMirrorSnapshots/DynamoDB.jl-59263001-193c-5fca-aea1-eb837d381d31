#  _____ _____ ____ _____ ____        ____        ____  ___   ___  ____
# |_   _| ____/ ___|_   _/ ___|      |  _ \      / ___|/ _ \ / _ \|  _ \
#   | | |  _| \___ \ | | \___ \ _____| |_) |____| |  _| | | | | | | | | |
#   | | | |___ ___) || |  ___) |_____|  _ <_____| |_| | |_| | |_| | |_| |
#   |_| |_____|____/ |_| |____/      |_| \_\     \____|\___/ \___/|____/


# NOTE TO READERS: These tests validate against the json generation
# functions. For tests dealing directly with DynamoDB, check out the
# integration tests.


## GET_ITEM

# helper to make get_item_query_dict match get_item's iterface
get_item_dict(table :: DynamoTable, key, range=nothing;
              consistant_read=true, only_returning=nothing :: Union{Void, Array{DynamoReference}}) =
    DynamoDB.get_item_query_dict(table, key, range, consistant_read, only_returning)

@test get_item_dict(foo_basic, "asdf") ==
    Dict("TableName" => "foo_basic", "ConsistentRead" => true,
         "Key" => Dict("a" => Dict("S" => "asdf")))

@test get_item_dict(foo_range, "asdf", 3) ==
    Dict("TableName" => "foo_range", "ConsistentRead" => true,
         "Key" => Dict("a" => Dict("S" => "asdf"), "b" => Dict("N" => "3")))

@test get_item_dict(foo_basic, "asdf"; consistant_read=false) ==
    Dict("TableName" => "foo_basic", "ConsistentRead" => false,
         "Key" => Dict("a" => Dict("S" => "asdf")))

@test get_item_dict(foo_basic, "asdf"; consistant_read=false, only_returning=[attr("a")]) ==
    Dict("TableName" => "foo_basic", "ConsistentRead" => false, "ProjectionExpression" => "#1",
         "ExpressionAttributeNames" => Dict("#1" => "a"), "Key" => Dict("a" => Dict("S" => "asdf")))


## BATCH_GET_ITEM

@test DynamoDB.batch_get_item_dict([DynamoDB.batch_get_item_part(foo_basic, 1, 2)]) ==
    Dict("RequestItems" => Dict("foo_basic" => Dict("ConsistentRead" => true,
                                                    "Keys" => [Dict("a" => Dict("N" => "1")),
                                                               Dict("a" => Dict("N" => "2"))])))

@test DynamoDB.batch_get_item_dict([DynamoDB.batch_get_item_part(foo_range, (1, 2), (3, 4))]) ==
    Dict("RequestItems" => Dict("foo_range" =>
                                Dict("ConsistentRead" => true,
                                     "Keys" => [Dict("a" => Dict("N" => "1"), "b" => Dict("N" => "2")),
                                                Dict("a" => Dict("N" => "3"), "b" => Dict("N" => "4"))])))

@test DynamoDB.batch_get_item_dict([DynamoDB.batch_get_item_part(foo_basic, 1, 2),
                                    DynamoDB.batch_get_item_part(foo_range, (1, 2), (3, 4))]) ==
    Dict("RequestItems"=>Dict("foo_basic"=>Dict("Keys"=>[Dict("a"=>Dict("N"=>"1")),
                                                         Dict("a"=>Dict("N"=>"2"))],
                                                "ConsistentRead"=>true),
                              "foo_range"=>Dict("Keys"=>[Dict("a"=>Dict("N"=>"1"),"b"=>Dict("N"=>"2")),
                                                         Dict("a"=>Dict("N"=>"3"),"b"=>Dict("N"=>"4"))],
                                                "ConsistentRead"=>true)))


## PUT ITEM

@test DynamoDB.put_item_dict(foo_basic, Foo(1, 2)) ==
    Dict("TableName" => "foo_basic",
         "Item" => Dict("a" => Dict("N" => "1"),
                        "b" => Dict("N" => "2")))

@test DynamoDB.put_item_dict(foo_basic, Foo(1, 2); conditions=attr("b") < 2) ==
    Dict("TableName" => "foo_basic",
         "Item" => Dict("a" => Dict("N" => "1"),
                        "b" => Dict("N" => "2")),
         "ConditionExpression" => "(#1) < (:2)",
         "ExpressionAttributeNames" => Dict("#1" => "b"),
         "ExpressionAttributeValues" => Dict(":2" => Dict("N" => "2")))

@test DynamoDB.put_item_dict(foo_basic, Foo(1, 2); conditions=attr("b") < 2, return_old=true) ==
    Dict("TableName" => "foo_basic",
         "Item" => Dict("a" => Dict("N" => "1"),
                        "b" => Dict("N" => "2")),
         "ReturnValues" => "ALL_OLD",
         "ConditionExpression" => "(#1) < (:2)",
         "ExpressionAttributeNames" => Dict("#1" => "b"),
         "ExpressionAttributeValues" => Dict(":2" => Dict("N" => "2")))


## BATCH WRITE ITEM

@test DynamoDB.batch_write_item_dict([DynamoDB.batch_delete_part(foo_basic, 1, 2)]) ==
    [Dict("foo_basic" => [Dict("DeleteRequest" =>
                               Dict("Key" => Dict("a" => Dict("N" => "1")))),
                          Dict("DeleteRequest" =>
                               Dict("Key" => Dict("a" => Dict("N" => "2"))))])]


@test DynamoDB.batch_write_item_dict([DynamoDB.batch_put_part(foo_basic, Foo(1, 2), Foo(3, 4))]) ==
    [Dict("foo_basic" => [Dict("PutRequest" =>
                               Dict("Item" => Dict("a" => Dict("N" => "1"),
                                                   "b" => Dict("N" => "2")))),
                          Dict("PutRequest" =>
                               Dict("Item" => Dict("a" => Dict("N" => "3"),
                                                   "b" => Dict("N" => "4"))))])]

@test DynamoDB.batch_write_item_dict([DynamoDB.batch_delete_part(foo_basic, 1, 2),
                                      DynamoDB.batch_put_part(foo_basic, Foo(1, 2), Foo(3, 4))]) ==
    [Dict("foo_basic" => [Dict("DeleteRequest" =>
                               Dict("Key" => Dict("a" => Dict("N" => "1")))),
                          Dict("DeleteRequest" =>
                               Dict("Key" => Dict("a" => Dict("N" => "2")))),
                          Dict("PutRequest" =>
                               Dict("Item" => Dict("a" => Dict("N" => "1"),
                                                   "b" => Dict("N" => "2")))),
                          Dict("PutRequest" =>
                               Dict("Item" => Dict("a" => Dict("N" => "3"),
                                                   "b" => Dict("N" => "4"))))])]


## UPDATE ITEM

@test DynamoDB.update_item_dict(foo_basic, 1, nothing, [assign(attr("a"), 22)]) ==
    Dict("TableName" => "foo_basic",
         "Key" => Dict("a" => Dict("N" => "1")),
         "ReturnValues" => "NONE",
         "UpdateExpression" => "SET #1 = :2",
         "ExpressionAttributeNames" => Dict("#1" => "a"),
         "ExpressionAttributeValues" => Dict(":2" => Dict("N" => "22")))

@test DynamoDB.update_item_dict(foo_basic, 1, nothing, [assign(attr("a"), 22)]; conditions=attr("b") <= 2) ==
    Dict("TableName" => "foo_basic",
         "Key" => Dict("a" => Dict("N" => "1")),
         "ReturnValues" => "NONE",
         "UpdateExpression" => "SET #1 = :2",
         "ConditionExpression" => "(#3) <= (:4)",
         "ExpressionAttributeNames" => Dict("#1" => "a", "#3" => "b"),
         "ExpressionAttributeValues" => Dict(":2" => Dict("N" => "22"), ":4" => Dict("N" => "2")))


## DELETE ITEM

@test DynamoDB.delete_item_dict(foo_basic, 1) ==
    Dict("TableName" => "foo_basic",
         "Key" => Dict("a" => Dict("N" => "1")))

@test DynamoDB.delete_item_dict(foo_basic, 1; conditions=attr("b") > 2) ==
    Dict("TableName" => "foo_basic",
         "Key" => Dict("a" => Dict("N" => "1")),
         "ConditionExpression" => "(#1) > (:2)",
         "ExpressionAttributeNames" => Dict("#1" => "b"),
         "ExpressionAttributeValues" => Dict(":2" => Dict("N" => "2")))


## QUERY

@test DynamoDB.query_dict(foo_range, 77, attr("b") > 17) ==
    Dict("TableName" => "foo_range",
         "KeyConditionExpression" => "((#1) = (:2)) AND ((#3) > (:4))",
         "ExpressionAttributeNames" => Dict("#1" => "a", "#3" => "b"),
         "ExpressionAttributeValues" => Dict(":2" => Dict("N" => "77"),
                                             ":4" => Dict("N" => "17")))

@test DynamoDB.query_dict(foo_range, 77, attr("b") > 17;
                 filter=attr("c") != "cat", scan_index_forward=false, limit=100) ==
    Dict("TableName" => "foo_range",
         "KeyConditionExpression" => "((#1) = (:2)) AND ((#3) > (:4))",
         "FilterExpression" => "(#5) <> (:6)",
         "ScanIndexForward" => false,
         "Limit" => 100,
         "ExpressionAttributeNames" => Dict("#1" => "a", "#3" => "b", "#5" => "c"),
         "ExpressionAttributeValues" => Dict(":2" => Dict("N" => "77"),
                                             ":4" => Dict("N" => "17"),
                                             ":6" => Dict("S" => "cat")))

@test DynamoDB.query_dict(foo_range, 77, attr("b") > 17;
                 projection = [attr("one"), attr("two")], consistant_read=false, index_name="MyIndex",
                 filter=attr("c") != "cat", scan_index_forward=false, limit=100) ==
    Dict("TableName" => "foo_range",
         "KeyConditionExpression" => "((#1) = (:2)) AND ((#3) > (:4))",
         "FilterExpression" => "(#7) <> (:8)",
         "ProjectionExpression" => "#5, #6",
         "ScanIndexForward" => false, "ConsistentRead" => false,
         "IndexName" => "MyIndex", "Limit" => 100,
         "ExpressionAttributeNames" => Dict("#1" => "a", "#3" => "b", "#5" => "one", "#6" => "two", "#7" => "c"),
         "ExpressionAttributeValues" => Dict(":2" => Dict("N" => "77"),
                                             ":4" => Dict("N" => "17"),
                                             ":8" => Dict("S" => "cat")))


## SCAN

@test DynamoDB.scan_dict(foo_range, attr("c") > 17) ==
    Dict("TableName" => "foo_range",
         "FilterExpression" => "(#1) > (:2)",
         "ExpressionAttributeNames" => Dict("#1" => "c"),
         "ExpressionAttributeValues" => Dict(":2" => Dict("N" => "17")))

@test DynamoDB.scan_dict(foo_range, attr("c") == 17;
                projection=[attr("atty1"), attr("atty2")], consistant_read=true, scan_index_forward=false,
                limit=31, segment=3, total_segments=17) ==
    Dict("TableName" => "foo_range",
         "ConsistentRead" => true,
         "ScanIndexForward" => false,
         "Segment" => 3,
         "TotalSegments" => 17,
         "Limit" => 31,
         "FilterExpression" => "(#1) = (:2)",
         "ProjectionExpression" => "#3, #4",
         "ExpressionAttributeNames" => Dict("#1" => "c", "#3" => "atty1", "#4" => "atty2"),
         "ExpressionAttributeValues" => Dict(":2" => Dict("N" => "17")))
