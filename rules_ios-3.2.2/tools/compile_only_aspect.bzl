"""
Helper aspect to do objc and swift compilation only for fast iteration cycles on
big mono-repo refactors.

In a mono-repo a developer will change much objc and swift source code. We don't
want to link or codesign the intermediates. This program collects the relevate
compile actions

bazel build -s tests/ios/app:App  --aspects rules/compile_only_aspect.bzl%compile_only_aspect --output_groups=compiles
"""

def _compile_only_aspect_impl(target, ctx):
    outs = depset([])

    swift_rule_kinds = ["swift_library", "swift_test"]
    objc_rule_kinds = ["objc_library"]
    
    for action in target.actions:
        if "tests/ios/app/App/main.m" in str(action) and (action.mnemonic == "ObjcCompile" or action.mnemonic == "CppCompile"):
            print(str(action) + str(action.inputs.to_list()))  # this output don't contain compiler need header
            found_objc_arc = False
            for input in action.inputs.to_list():
                if input.path.endswith("objc_arc"):
                    found_objc_arc = True
            if not found_objc_arc:
                fail("not found any input has suffix objc_arc")

    # Consider in Swift compilation how to only generate the intefaces
    # through the feature of interface splitting
    if ctx.rule.kind in swift_rule_kinds:
        for action in target.actions:
            if action.mnemonic == "SwiftCompile":
                outs = action.outputs
                break
    elif ctx.rule.kind in objc_rule_kinds:
        outs = depset([], transitive = [action.outputs for action in target.actions if action.mnemonic == "ObjcCompile"])
    deps = getattr(ctx.rule.attr, "deps", [])
    transitive = [dep[OutputGroupInfo].compiles for dep in deps if OutputGroupInfo in dep]
    compile_set = depset([], transitive = [outs] + transitive)
    return [OutputGroupInfo(compiles = compile_set)]

compile_only_aspect = aspect(
    implementation = _compile_only_aspect_impl,
    attr_aspects = ["deps"],
)
