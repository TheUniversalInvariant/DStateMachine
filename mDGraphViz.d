module mDGraphViz;

import std.format : format;

// Set GraphVizBin directory
enum GraphVizBin = ``;

struct Option {
    string[string] option;
    alias option this;

    auto toString() {
        if (option.length == 0) return "";
        auto s = " [ ";
        foreach (k, v; option) {
            s ~= "%s = \"%s\", ".format(k, v);
        }
        s = s[0 .. $-2] ~ " ]";
        return s;
    }
}

private struct Edge {
    string ark;
    Node src, dst;
    Option option;

    auto toString() {
        return "\"%s\" %s \"%s\" %s;\n".format(src.label, ark, dst.label, option);
    }
}

private class Node {
    string label;
    Option option;
    size_t nIn = 0, nOut = 0;

    this(string label) {
        import std.string : replace;
        this.label = label.replace("\"", "\\\"");
    }

    this(string label, Option option) {
        this(label);
        this.option = option;
    }

    auto info() {
        if (option.length == 0) return "";
        auto s = "\"%s\" %s;\n".format(label, option);
        return s;
    }
}


abstract class Graph {
    import std.conv : to;

    // TODO use Set
    Node[string] nodes;
    Edge[string] edges;
    Option graphOpt, nodeOpt, edgeOpt;

    ref auto node(ref Node d) { return d; }

    ref auto node(T)(T t) {
        string[string] opt;
        return node(t, opt);
    }

    ref auto node(T)(T t, string[string] option) {
        auto key = t.to!string;
        if (key !in this.nodes) {
            this.nodes[key] = new Node(t.to!string, Option(option));
        }
        return this.nodes[key];
    }

    auto edge(S, D)(S src, D dst,) {
        string[string] opt;
        return edge(src, dst, opt);
    }

    auto edge(S, D)(S src, D dst, string[string] option) {
        auto s = node(src);
        auto d = node(dst);
        auto e = Edge(this.ark, s, d, Option(option));
        ++s.nOut;
        ++d.nIn;
        this.edges[e.to!string] = e;
        return e;
    }

    abstract string typename();
    abstract string ark();

    override string toString() {
        import std.array : array;
        import std.algorithm : uniq, map, sort;
        auto s = this.typename ~ " g{\n";

        if (graphOpt.length > 0) s ~= "graph %s;\n".format(graphOpt);
        if (nodeOpt.length > 0) s ~= "node %s;\n".format(nodeOpt);
        if (edgeOpt.length > 0) s ~= "edge %s;\n".format(edgeOpt);

        foreach (k, n; this.nodes) 
		{
            s ~= n.info;
        }
        foreach (k, e; this.edges) 
		{
            s ~= k;
        }
        s ~= "}\n";
        return s;
    }

    void save(string fn, bool useNeato = false, bool saveDot = false) 
	{		
        import std.stdio : File;
		import std.process, std.file, std.path;
		fn = stripExtension(fn)~".dot";
		auto tfn = "__tmp__123234.tmp";
		if (!useNeato) tfn = fn;			
        auto f = File(tfn, "w");
        f.write(this.toString());
		f.detach();

		auto sss = stripExtension(fn);
		if (useNeato) { executeShell(`"`~GraphVizBin~`neato.exe" `~tfn~` > `~fn); remove(tfn); }

		executeShell(GraphVizBin~`dot.exe `~fn~` -Tpng -O`);
		if (!saveDot) remove(fn);
		rename(fn~".png", stripExtension(fn)~".png");
    }
	
}

class Undirected : Graph {
    override string typename() { return "graph"; }
    override string ark() { return "--"; }
}

class Directed : Graph {
    override string typename() { return "digraph"; }
    override string ark() { return "->"; }
}


///
unittest {
    import std.stdio;
    import std.format;
    import dgraphviz;

    struct A {
        auto toString() {
            return "A\n\"struct\"";
        }
    }

    auto g = new Directed;
    A a;
    with (g) {
        node(a, ["shape": "box", "color": "#ff0000"]);
        edge(a, true);
        edge(a, 1, ["style": "dashed", "label": "a-to-1"]);
        edge(true, "foo");
    }
    g.save("simple.dot");
}

Directed libraryDependency(string root, string prefix="",
                           bool verbose=false, size_t maxDepth=3) {
    import std.file : dirEntries, SpanMode, readText;
    import std.format : formattedRead;
    import std.string : split, strip, join, endsWith, replace, startsWith;
    import std.algorithm : map, canFind, min, any, filter;
    import std.stdio : writefln;

    auto g = new Directed;

    with (g) {
        enum invalidTokens = ["\"", "$", "/", "\\"];
        auto removeSub(string s) {
            return s.split(".")[0..min($, maxDepth)].join(".");
        }

        void registerEdge(string src, string dst) {
            dst = dst.strip;
            // FIXME follow import expr spec.
            if (invalidTokens.map!(i => dst.canFind(i)).any) {
                return;
            } else if (dst.canFind(":")) {
                registerEdge(src, dst.split(":")[0]);
            } else if (dst.canFind(",")) {
                foreach (d; split(dst, ",")) {
                    registerEdge(src, d);
                }
            } else if (dst.canFind(" ")) {
                return;
            } else if (dst.canFind("std.")) {
                if (verbose) writefln("%s -> %s", src, dst);
                edge(removeSub(src), removeSub(dst));
            }
        }

        auto dfiles = dirEntries(root, SpanMode.depth)
            .filter!(f => f.name.startsWith(root ~ prefix) && f.name.endsWith(".d"));
        foreach (dpath; dfiles) {
            auto src = dpath[root.length .. $].replace("/", ".")[0 .. $-2];
            try {
                foreach (txt; dpath.readText.split("import")[1..$]) {
                    txt = "import " ~ txt;
                    string dst, rest;
                    txt.formattedRead!"import %s;%s"(dst, rest);
                    if (verbose) writefln("%s ---------> %s", src, dst);
                    registerEdge(src, dst);
                }
            } catch (Exception e) {
                // FIXME display warnings
            }
        }
    }
    return g;
}

///
unittest {
    import std.path;
    import std.process;

    auto dc = environment.get("DC");
    assert(dc != "", "use DUB or set DC enviroment variable");
    auto which = executeShell("which " ~ dc);
    assert(which.status == 0);
    version(DigitalMars) {
        auto root = which.output.dirName ~ "/../../src/phobos/";
    }
    version(LDC) {
        auto root = which.output.dirName ~ "/../import/";
    }

    auto g = libraryDependency(root, "std/range", true);
    g.save("range.dot");
}
