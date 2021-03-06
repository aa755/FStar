
let halloc = (fun ( init ) -> ref init)

let salloc = (fun ( init ) ->  Camlstack.mkref init)

let memread = (fun ( r ) -> !r )

let memwrite = (fun ( r ) ( v ) -> r := v )

let pushStackFrame = (fun ( _ ) -> Camlstack.push_frame ())

let popStackFrame = (fun ( _ ) -> Camlstack.pop_frame ())

let get = (fun ( _ ) -> ())


let lalloc = (fun ( v ) -> (FStar_All.failwith "unexpected. extraction should have redirected calls to this function"))

let llift = (fun ( f ) ( l ) -> (f l))
